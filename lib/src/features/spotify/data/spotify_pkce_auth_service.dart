import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:party_queue_app/src/features/spotify/data/spotify_app_config.dart';
import 'package:party_queue_app/src/features/spotify/data/spotify_browser_bridge.dart'
    as browser;
import 'package:party_queue_app/src/features/spotify/domain/models/spotify_connection_state.dart';
import 'package:party_queue_app/src/features/spotify/domain/spotify_auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SpotifyPkceAuthService implements SpotifyAuthService {
  SpotifyPkceAuthService({
    required SpotifyAppConfig config,
    http.Client? httpClient,
    Future<SharedPreferences> Function()? preferencesLoader,
    Uri Function()? currentUri,
    Future<void> Function(Uri uri)? redirectTo,
    void Function(Uri uri)? replaceCurrentUrl,
    DateTime Function()? now,
    bool? isWeb,
  }) : _config = config,
       _httpClient = httpClient ?? http.Client(),
       _preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance,
       _currentUri = currentUri ?? browser.getCurrentUri,
       _redirectTo = redirectTo ?? browser.redirectTo,
       _replaceCurrentUrl = replaceCurrentUrl ?? browser.replaceCurrentUrl,
       _now = now ?? DateTime.now,
       _isWeb = isWeb ?? kIsWeb;

  static const String _accessTokenKey = 'spotify.auth.access_token';
  static const String _refreshTokenKey = 'spotify.auth.refresh_token';
  static const String _expiresAtKey = 'spotify.auth.expires_at';
  static const String _scopeKey = 'spotify.auth.scope';
  static const String _stateKey = 'spotify.auth.pending_state';
  static const String _verifierKey = 'spotify.auth.code_verifier';

  final SpotifyAppConfig _config;
  final http.Client _httpClient;
  final Future<SharedPreferences> Function() _preferencesLoader;
  final Uri Function() _currentUri;
  final Future<void> Function(Uri uri) _redirectTo;
  final void Function(Uri uri) _replaceCurrentUrl;
  final DateTime Function() _now;
  final bool _isWeb;

  @override
  Future<SpotifyConnectionState> connect() async {
    final restored = await restoreSession();
    if (restored.spotifyConnected) {
      return restored;
    }
    if (!_config.isConfigured) {
      return const SpotifyConnectionState(
        errorMessage:
            'Spotify Client ID oder Redirect URI fehlen. Bitte per --dart-define konfigurieren.',
      );
    }
    if (!_isWeb) {
      return SpotifyConnectionState(
        errorMessage:
            'Echte Spotify-Auth ist aktuell nur fuer ${_config.primaryPlatform} vorbereitet.',
      );
    }

    final prefs = await _preferencesLoader();
    final verifier = _generateCodeVerifier();
    final state = _generateState();
    await prefs.setString(_stateKey, state);
    await prefs.setString(_verifierKey, verifier);
    await _redirectTo(_buildAuthorizationUri(verifier, state));
    return const SpotifyConnectionState();
  }

  @override
  Future<SpotifyConnectionState> restoreSession() async {
    if (!_config.isConfigured) {
      return const SpotifyConnectionState(
        errorMessage:
            'Spotify Client ID oder Redirect URI fehlen. Bitte per --dart-define konfigurieren.',
      );
    }
    if (!_isWeb) {
      return SpotifyConnectionState(
        errorMessage:
            'Echte Spotify-Auth ist aktuell nur fuer ${_config.primaryPlatform} vorbereitet.',
      );
    }

    final callbackState = await _tryCompleteAuthorizationCallback();
    if (callbackState != null) {
      return callbackState;
    }
    return _restoreStoredSession();
  }

  @override
  Future<String?> getValidAccessToken() async {
    if (!_config.isConfigured) {
      return null;
    }
    final prefs = await _preferencesLoader();
    final accessToken = prefs.getString(_accessTokenKey);
    if (accessToken == null || accessToken.isEmpty) {
      return null;
    }
    final expiresAtMillis = prefs.getInt(_expiresAtKey);
    if (expiresAtMillis == null) {
      return accessToken;
    }
    final expiresAt = DateTime.fromMillisecondsSinceEpoch(expiresAtMillis);
    if (_now().isBefore(expiresAt.subtract(const Duration(seconds: 30)))) {
      return accessToken;
    }
    final refreshed = await _refreshAccessToken();
    return refreshed.$1;
  }

  @override
  Future<SpotifyConnectionState> disconnect() async {
    final prefs = await _preferencesLoader();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_expiresAtKey);
    await prefs.remove(_scopeKey);
    await prefs.remove(_stateKey);
    await prefs.remove(_verifierKey);
    return const SpotifyConnectionState();
  }

  Future<SpotifyConnectionState?> _tryCompleteAuthorizationCallback() async {
    final uri = _currentUri();
    final code = uri.queryParameters['code'];
    final error = uri.queryParameters['error'];
    final state = uri.queryParameters['state'];
    if (code == null && error == null) {
      return null;
    }

    final prefs = await _preferencesLoader();
    if (error != null) {
      await prefs.remove(_stateKey);
      await prefs.remove(_verifierKey);
      _replaceCurrentUrl(_cleanUri(uri));
      return SpotifyConnectionState(
        errorMessage: 'Spotify Auth Fehler: $error',
      );
    }

    final expectedState = prefs.getString(_stateKey);
    final verifier = prefs.getString(_verifierKey);
    if (state == null ||
        expectedState == null ||
        verifier == null ||
        state != expectedState) {
      _replaceCurrentUrl(_cleanUri(uri));
      return const SpotifyConnectionState(
        errorMessage: 'Spotify Callback konnte nicht verifiziert werden.',
      );
    }

    final tokenResponse = await _httpClient.post(
      Uri.parse('${_config.accountsBaseUrl}/api/token'),
      headers: const <String, String>{
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: <String, String>{
        'client_id': _config.clientId,
        'grant_type': 'authorization_code',
        'code': code!,
        'redirect_uri': _config.redirectUri,
        'code_verifier': verifier,
      },
    );
    if (tokenResponse.statusCode < 200 || tokenResponse.statusCode >= 300) {
      _replaceCurrentUrl(_cleanUri(uri));
      return SpotifyConnectionState(
        errorMessage:
            'Spotify Token-Austausch fehlgeschlagen (${tokenResponse.statusCode}).',
      );
    }

    final payload = jsonDecode(tokenResponse.body) as Map<String, dynamic>;
    final grantedScopes = _parseScopes(payload['scope'] as String?);
    final expiresIn = (payload['expires_in'] as num?)?.toInt() ?? 3600;
    final expiresAt = _now().add(Duration(seconds: expiresIn));
    await prefs.setString(_accessTokenKey, payload['access_token'] as String);
    final refreshToken = payload['refresh_token'] as String?;
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await prefs.setString(_refreshTokenKey, refreshToken);
    }
    await prefs.setInt(_expiresAtKey, expiresAt.millisecondsSinceEpoch);
    await prefs.setString(_scopeKey, grantedScopes.join(' '));
    await prefs.remove(_stateKey);
    await prefs.remove(_verifierKey);
    _replaceCurrentUrl(_cleanUri(uri));
    return _fetchConnectionProfile(
      grantedScopes: grantedScopes,
      accessTokenExpiresAt: expiresAt,
    );
  }

  Future<SpotifyConnectionState> _restoreStoredSession() async {
    final prefs = await _preferencesLoader();
    final token = await getValidAccessToken();
    if (token == null) {
      return const SpotifyConnectionState();
    }
    final expiresAtMillis = prefs.getInt(_expiresAtKey);
    return _fetchConnectionProfile(
      grantedScopes: _parseScopes(prefs.getString(_scopeKey)),
      accessTokenExpiresAt: expiresAtMillis == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(expiresAtMillis),
    );
  }

  Future<SpotifyConnectionState> _fetchConnectionProfile({
    required List<String> grantedScopes,
    required DateTime? accessTokenExpiresAt,
  }) async {
    final accessToken = await getValidAccessToken();
    if (accessToken == null) {
      return const SpotifyConnectionState(
        errorCode: 'spotify-token-missing',
        errorMessage: 'Spotify-Session konnte nicht wiederhergestellt werden.',
      );
    }

    final response = await _httpClient.get(
      Uri.parse('${_config.apiBaseUrl}/me'),
      headers: <String, String>{'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return SpotifyConnectionState(
        grantedScopes: grantedScopes,
        accessTokenExpiresAt: accessTokenExpiresAt,
        errorCode: 'spotify-profile-load-failed',
        errorMessage:
            'Spotify-Profil konnte nicht geladen werden (${response.statusCode}).',
      );
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final product = (payload['product'] as String?)?.trim().toLowerCase();
    final displayName =
        (payload['display_name'] as String?)?.trim().isNotEmpty == true
        ? (payload['display_name'] as String).trim()
        : null;
    final userId = (payload['id'] as String?)?.trim();
    final isPremium = product == 'premium';
    return SpotifyConnectionState(
      spotifyConnected: true,
      spotifyUserId: userId == null || userId.isEmpty ? null : userId,
      displayName: displayName,
      accountProduct: product,
      premiumConfirmed: isPremium,
      grantedScopes: grantedScopes,
      accessTokenExpiresAt: accessTokenExpiresAt,
      errorCode: isPremium ? null : 'spotify-premium-required',
      errorMessage: isPremium
          ? null
          : 'Spotify Premium ist fuer den Host erforderlich.',
    );
  }

  Future<(String?, DateTime?)> _refreshAccessToken() async {
    final prefs = await _preferencesLoader();
    final refreshToken = prefs.getString(_refreshTokenKey);
    if (refreshToken == null || refreshToken.isEmpty) {
      return (null, null);
    }
    final response = await _httpClient.post(
      Uri.parse('${_config.accountsBaseUrl}/api/token'),
      headers: const <String, String>{
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: <String, String>{
        'client_id': _config.clientId,
        'grant_type': 'refresh_token',
        'refresh_token': refreshToken,
      },
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return (null, null);
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final accessToken = payload['access_token'] as String?;
    if (accessToken == null || accessToken.isEmpty) {
      return (null, null);
    }
    final expiresIn = (payload['expires_in'] as num?)?.toInt() ?? 3600;
    final expiresAt = _now().add(Duration(seconds: expiresIn));
    await prefs.setString(_accessTokenKey, accessToken);
    await prefs.setInt(_expiresAtKey, expiresAt.millisecondsSinceEpoch);
    final scopes = payload['scope'] as String?;
    if (scopes != null) {
      await prefs.setString(_scopeKey, scopes);
    }
    final nextRefresh = payload['refresh_token'] as String?;
    if (nextRefresh != null && nextRefresh.isNotEmpty) {
      await prefs.setString(_refreshTokenKey, nextRefresh);
    }
    return (accessToken, expiresAt);
  }

  Uri _buildAuthorizationUri(String verifier, String state) {
    final challenge = _codeChallenge(verifier);
    return Uri.parse('${_config.accountsBaseUrl}/authorize').replace(
      queryParameters: <String, String>{
        'client_id': _config.clientId,
        'response_type': 'code',
        'redirect_uri': _config.redirectUri,
        'code_challenge_method': 'S256',
        'code_challenge': challenge,
        'state': state,
        'scope': _config.scopes.join(' '),
      },
    );
  }

  Uri _cleanUri(Uri uri) {
    return uri.replace(queryParameters: <String, String>{}, fragment: '');
  }

  String _generateCodeVerifier() {
    final random = Random.secure();
    final values = List<int>.generate(64, (_) => random.nextInt(256));
    return base64UrlEncode(values).replaceAll('=', '');
  }

  String _generateState() {
    final random = Random.secure();
    final values = List<int>.generate(16, (_) => random.nextInt(256));
    return base64UrlEncode(values).replaceAll('=', '');
  }

  String _codeChallenge(String verifier) {
    final digest = sha256.convert(utf8.encode(verifier));
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }

  List<String> _parseScopes(String? rawScopes) {
    if (rawScopes == null || rawScopes.trim().isEmpty) {
      return const <String>[];
    }
    return rawScopes.split(' ').where((scope) => scope.isNotEmpty).toList();
  }
}
