import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:party_queue_app/src/features/party/domain/models/spotify_track.dart';
import 'package:party_queue_app/src/features/spotify/data/spotify_app_config.dart';
import 'package:party_queue_app/src/features/spotify/domain/spotify_auth_service.dart';
import 'package:party_queue_app/src/features/spotify/domain/spotify_catalog_service.dart';

class SpotifyWebCatalogService implements SpotifyCatalogService {
  SpotifyWebCatalogService({
    required SpotifyAppConfig config,
    required SpotifyAuthService authService,
    http.Client? httpClient,
  }) : _config = config,
       _authService = authService,
       _httpClient = httpClient ?? http.Client();

  final SpotifyAppConfig _config;
  final SpotifyAuthService _authService;
  final http.Client _httpClient;

  @override
  Future<List<SpotifyTrack>> searchTracks(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) {
      return const <SpotifyTrack>[];
    }

    final accessToken = await _authService.getValidAccessToken();
    if (accessToken == null) {
      return const <SpotifyTrack>[];
    }

    final response = await _httpClient.get(
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
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return const <SpotifyTrack>[];
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final tracksPayload = payload['tracks'] as Map<String, dynamic>?;
    final items = tracksPayload?['items'] as List<dynamic>? ?? const <dynamic>[];

    return items
        .whereType<Map<String, dynamic>>()
        .map(_toSpotifyTrack)
        .whereType<SpotifyTrack>()
        .toList();
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
