import 'dart:convert';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:party_queue_app/src/features/party/domain/models/spotify_track.dart';
import 'package:party_queue_app/src/features/spotify/data/spotify_app_config.dart';
import 'package:party_queue_app/src/features/spotify/domain/spotify_auth_service.dart';
import 'package:party_queue_app/src/features/spotify/domain/spotify_catalog_service.dart';

class SpotifyWebCatalogService implements SpotifyCatalogService {
  static const List<String> _suggestionSeeds = <String>[
    'Mr. Brightside',
    'Blinding Lights',
    'Bohemian Rhapsody',
    'Save Your Tears',
    'bad guy',
  ];

  SpotifyWebCatalogService({
    required SpotifyAppConfig config,
    required SpotifyAuthService authService,
    http.Client? httpClient,
    Duration requestTimeout = const Duration(seconds: 5),
  }) : _config = config,
       _authService = authService,
       _httpClient = httpClient ?? http.Client(),
       _requestTimeout = requestTimeout;

  final SpotifyAppConfig _config;
  final SpotifyAuthService _authService;
  final http.Client _httpClient;
  final Duration _requestTimeout;

  void _logSuggestions(String message) {
    debugPrint('[Suggestions][Catalog] $message');
  }

  @override
  Future<List<SpotifyTrack>> searchTracks(String query) async {
    final normalized = query.trim();
    _logSuggestions('searchTracks start query="$normalized"');
    if (normalized.isEmpty) {
      _logSuggestions('searchTracks short-circuit blank query');
      return const <SpotifyTrack>[];
    }

    final accessToken = await _authService.getValidAccessToken();
    if (accessToken == null) {
      _logSuggestions('searchTracks no access token query="$normalized"');
      return const <SpotifyTrack>[];
    }

    http.Response response;
    try {
      _logSuggestions('searchTracks request query="$normalized"');
      response = await _httpClient
          .get(
            Uri.parse('${_config.apiBaseUrl}/search').replace(
              queryParameters: <String, String>{
                'q': normalized,
                'type': 'track',
                'limit': '10',
                'market': 'from_token',
              },
            ),
            headers: <String, String>{
              'Authorization': 'Bearer $accessToken',
            },
          )
          .timeout(_requestTimeout);
    } on TimeoutException {
      _logSuggestions('searchTracks timeout query="$normalized"');
      return const <SpotifyTrack>[];
    } catch (_) {
      _logSuggestions('searchTracks catch query="$normalized"');
      return const <SpotifyTrack>[];
    }

    _logSuggestions(
      'searchTracks response query="$normalized" status=${response.statusCode}',
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      _logSuggestions('searchTracks non-2xx query="$normalized"');
      return const <SpotifyTrack>[];
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final tracksPayload = payload['tracks'] as Map<String, dynamic>?;
    final items = tracksPayload?['items'] as List<dynamic>? ?? const <dynamic>[];

    final results = items
        .whereType<Map<String, dynamic>>()
        .map(_toSpotifyTrack)
        .whereType<SpotifyTrack>()
        .toList();
    _logSuggestions(
      'searchTracks end query="$normalized" mapped=${results.length}',
    );
    return results;
  }

  @override
  Future<List<SpotifyTrack>> loadSuggestions() async {
    final suggestions = <SpotifyTrack>[];
    final seenTrackIds = <String>{};

    for (final seed in _suggestionSeeds) {
      final results = await searchTracks(seed);
      for (final track in results) {
        if (seenTrackIds.add(track.id)) {
          suggestions.add(track);
          break;
        }
      }
      if (suggestions.length == 3) {
        break;
      }
    }

    return suggestions.take(3).toList();
  }

  SpotifyTrack? _toSpotifyTrack(Map<String, dynamic> json) {
    final id = (json['id'] as String?)?.trim();
    final uri = (json['uri'] as String?)?.trim();
    final title = (json['name'] as String?)?.trim();
    if (id == null ||
        id.isEmpty ||
        uri == null ||
        uri.isEmpty ||
        title == null ||
        title.isEmpty) {
      return null;
    }

    final restrictions = json['restrictions'] as Map<String, dynamic>?;
    final isPlayable = json['is_playable'];
    if (isPlayable == false || restrictions != null) {
      return null;
    }

    final artists = (json['artists'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map((artist) => (artist['name'] as String?)?.trim())
        .whereType<String>()
        .where((artist) => artist.isNotEmpty)
        .toList();
    if (artists.isEmpty) {
      return null;
    }

    return SpotifyTrack(
      id: id,
      uri: uri,
      title: title,
      artist: artists.join(', '),
    );
  }
}
