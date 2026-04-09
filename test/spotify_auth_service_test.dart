import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:party_queue_app/src/features/spotify/data/spotify_app_config.dart';
import 'package:party_queue_app/src/features/spotify/data/spotify_pkce_auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const config = SpotifyAppConfig(
    clientId: 'spotify-client-id',
    redirectUri: 'http://127.0.0.1:3000/',
    scopes: <String>['user-read-private', 'user-modify-playback-state'],
  );

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test(
    'connect builds PKCE authorize redirect and stores verifier/state',
    () async {
      Uri? redirectedTo;
      final service = SpotifyPkceAuthService(
        config: config,
        isWeb: true,
        currentUri: () => Uri.parse(config.redirectUri),
        redirectTo: (uri) async {
          redirectedTo = uri;
        },
        replaceCurrentUrl: (_) {},
        httpClient: MockClient((_) async => http.Response('{}', 200)),
      );

      final state = await service.connect();

      expect(state.spotifyConnected, isFalse);
      expect(redirectedTo, isNotNull);
      expect(redirectedTo!.host, 'accounts.spotify.com');
      expect(redirectedTo!.path, '/authorize');
      expect(redirectedTo!.queryParameters['response_type'], 'code');
      expect(redirectedTo!.queryParameters['client_id'], config.clientId);
      expect(redirectedTo!.queryParameters['redirect_uri'], config.redirectUri);
      expect(redirectedTo!.queryParameters['code_challenge_method'], 'S256');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('spotify.auth.pending_state'), isNotEmpty);
      expect(prefs.getString('spotify.auth.code_verifier'), isNotEmpty);
    },
  );

  test(
    'restoreSession exchanges callback code for token and stores session',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'spotify.auth.pending_state': 'expected-state',
        'spotify.auth.code_verifier': 'expected-verifier',
      });

      final service = SpotifyPkceAuthService(
        config: config,
        isWeb: true,
        currentUri: () =>
            Uri.parse('${config.redirectUri}?code=abc123&state=expected-state'),
        replaceCurrentUrl: (_) {},
        redirectTo: (_) async {},
        httpClient: MockClient((request) async {
          if (request.url.toString() == '${config.accountsBaseUrl}/api/token') {
            final body = request.bodyFields;
            expect(body['grant_type'], 'authorization_code');
            expect(body['code'], 'abc123');
            expect(body['code_verifier'], 'expected-verifier');
            return http.Response(
              jsonEncode(<String, Object>{
                'access_token': 'real-access-token',
                'refresh_token': 'real-refresh-token',
                'scope': 'user-read-private user-modify-playback-state',
                'expires_in': 3600,
                'token_type': 'Bearer',
              }),
              200,
            );
          }
          expect(request.url.toString(), '${config.apiBaseUrl}/me');
          expect(request.headers['Authorization'], 'Bearer real-access-token');
          return http.Response(
            jsonEncode(<String, Object>{
              'id': 'spotify-host-1',
              'display_name': 'Real Host',
              'product': 'premium',
            }),
            200,
          );
        }),
      );

      final state = await service.restoreSession();

      expect(state.spotifyConnected, isTrue);
      expect(state.spotifyUserId, 'spotify-host-1');
      expect(state.displayName, 'Real Host');
      expect(state.accountProduct, 'premium');
      expect(state.premiumConfirmed, isTrue);
      expect(
        state.grantedScopes,
        containsAll(<String>[
          'user-read-private',
          'user-modify-playback-state',
        ]),
      );
      expect(await service.getValidAccessToken(), 'real-access-token');

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('spotify.auth.refresh_token'),
        'real-refresh-token',
      );
      expect(prefs.getString('spotify.auth.pending_state'), isNull);
      expect(prefs.getString('spotify.auth.code_verifier'), isNull);
    },
  );

  test(
    'restoreSession keeps host connected but blocks non-premium accounts',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'spotify.auth.access_token': 'real-access-token',
        'spotify.auth.refresh_token': 'real-refresh-token',
        'spotify.auth.expires_at': DateTime(
          2026,
          4,
          9,
          14,
        ).add(const Duration(hours: 1)).millisecondsSinceEpoch,
        'spotify.auth.scope': 'user-read-private user-modify-playback-state',
      });

      final service = SpotifyPkceAuthService(
        config: config,
        isWeb: true,
        currentUri: () => Uri.parse(config.redirectUri),
        replaceCurrentUrl: (_) {},
        redirectTo: (_) async {},
        now: () => DateTime(2026, 4, 9, 14),
        httpClient: MockClient((request) async {
          expect(request.url.toString(), '${config.apiBaseUrl}/me');
          return http.Response(
            jsonEncode(<String, Object>{
              'id': 'spotify-host-free',
              'display_name': 'Free Host',
              'product': 'free',
            }),
            200,
          );
        }),
      );

      final state = await service.restoreSession();

      expect(state.spotifyConnected, isTrue);
      expect(state.spotifyUserId, 'spotify-host-free');
      expect(state.displayName, 'Free Host');
      expect(state.accountProduct, 'free');
      expect(state.premiumConfirmed, isFalse);
      expect(state.errorCode, 'spotify-premium-required');
      expect(
        state.errorMessage,
        'Spotify Premium ist fuer den Host erforderlich.',
      );
    },
  );

  test('getValidAccessToken refreshes an expired token', () async {
    final now = DateTime(2026, 4, 9, 12);
    SharedPreferences.setMockInitialValues(<String, Object>{
      'spotify.auth.access_token': 'expired-token',
      'spotify.auth.refresh_token': 'refresh-token',
      'spotify.auth.expires_at': now
          .subtract(const Duration(seconds: 1))
          .millisecondsSinceEpoch,
    });

    final service = SpotifyPkceAuthService(
      config: config,
      isWeb: true,
      currentUri: () => Uri.parse(config.redirectUri),
      replaceCurrentUrl: (_) {},
      redirectTo: (_) async {},
      now: () => now,
      httpClient: MockClient((request) async {
        expect(request.bodyFields['grant_type'], 'refresh_token');
        expect(request.bodyFields['refresh_token'], 'refresh-token');
        return http.Response(
          jsonEncode(<String, Object>{
            'access_token': 'refreshed-token',
            'expires_in': 3600,
            'scope': 'user-read-private user-modify-playback-state',
            'token_type': 'Bearer',
          }),
          200,
        );
      }),
    );

    expect(await service.getValidAccessToken(), 'refreshed-token');
  });
}
