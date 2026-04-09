import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:party_queue_app/src/features/spotify/data/spotify_app_config.dart';
import 'package:party_queue_app/src/features/spotify/data/spotify_web_catalog_service.dart';
import 'package:party_queue_app/src/features/spotify/domain/models/spotify_connection_state.dart';
import 'package:party_queue_app/src/features/spotify/domain/spotify_auth_service.dart';

void main() {
  const config = SpotifyAppConfig(
    clientId: 'spotify-client-id',
    redirectUri: 'http://127.0.0.1:3000/',
    scopes: <String>[
      'user-read-private',
      'user-modify-playback-state',
      'user-read-playback-state',
    ],
  );

  test('searchTracks calls Spotify Search API and maps real tracks', () async {
    final service = SpotifyWebCatalogService(
      config: config,
      authService: StaticTokenAuthService(),
      httpClient: MockClient((request) async {
        expect(request.url.path, '/v1/search');
        expect(request.url.queryParameters['q'], 'Mr Brightside');
        expect(request.url.queryParameters['type'], 'track');
        expect(request.url.queryParameters['limit'], '10');
        expect(request.url.queryParameters['market'], 'from_token');
        expect(
          request.headers['Authorization'],
          'Bearer spotify-access-token',
        );
        return http.Response(
          jsonEncode(<String, Object>{
            'tracks': <String, Object>{
              'items': <Map<String, Object>>[
                <String, Object>{
                  'id': '3n3Ppam7vgaVa1iaRUc9Lp',
                  'uri': 'spotify:track:3n3Ppam7vgaVa1iaRUc9Lp',
                  'name': 'Mr. Brightside',
                  'artists': <Map<String, Object>>[
                    <String, Object>{'name': 'The Killers'},
                  ],
                },
              ],
            },
          }),
          200,
        );
      }),
    );

    final results = await service.searchTracks('Mr Brightside');

    expect(results, hasLength(1));
    expect(results.single.id, '3n3Ppam7vgaVa1iaRUc9Lp');
    expect(results.single.uri, 'spotify:track:3n3Ppam7vgaVa1iaRUc9Lp');
    expect(results.single.title, 'Mr. Brightside');
    expect(results.single.artist, 'The Killers');
  });

  test('searchTracks filters unplayable and restricted tracks', () async {
    final service = SpotifyWebCatalogService(
      config: config,
      authService: StaticTokenAuthService(),
      httpClient: MockClient((_) async {
        return http.Response(
          jsonEncode(<String, Object>{
            'tracks': <String, Object>{
              'items': <Map<String, Object>>[
                <String, Object>{
                  'id': 'playable-track',
                  'uri': 'spotify:track:playable-track',
                  'name': 'Playable Track',
                  'artists': <Map<String, Object>>[
                    <String, Object>{'name': 'Artist 1'},
                  ],
                },
                <String, Object>{
                  'id': 'blocked-track',
                  'uri': 'spotify:track:blocked-track',
                  'name': 'Blocked Track',
                  'is_playable': false,
                  'artists': <Map<String, Object>>[
                    <String, Object>{'name': 'Artist 2'},
                  ],
                },
                <String, Object>{
                  'id': 'restricted-track',
                  'uri': 'spotify:track:restricted-track',
                  'name': 'Restricted Track',
                  'restrictions': <String, Object>{'reason': 'market'},
                  'artists': <Map<String, Object>>[
                    <String, Object>{'name': 'Artist 3'},
                  ],
                },
              ],
            },
          }),
          200,
        );
      }),
    );

    final results = await service.searchTracks('track');

    expect(results.map((track) => track.id), <String>['playable-track']);
  });

  test('searchTracks returns empty list when auth token is missing', () async {
    final service = SpotifyWebCatalogService(
      config: config,
      authService: MissingTokenAuthService(),
    );

    expect(await service.searchTracks('anything'), isEmpty);
  });

  test('searchTracks returns empty list for blank query', () async {
    final service = SpotifyWebCatalogService(
      config: config,
      authService: StaticTokenAuthService(),
    );

    expect(await service.searchTracks('   '), isEmpty);
  });
}

class StaticTokenAuthService implements SpotifyAuthService {
  @override
  Future<SpotifyConnectionState> connect() async {
    throw UnimplementedError();
  }

  @override
  Future<SpotifyConnectionState> disconnect() async {
    throw UnimplementedError();
  }

  @override
  Future<String?> getValidAccessToken() async {
    return 'spotify-access-token';
  }

  @override
  Future<SpotifyConnectionState> restoreSession() async {
    throw UnimplementedError();
  }
}

class MissingTokenAuthService implements SpotifyAuthService {
  @override
  Future<SpotifyConnectionState> connect() async {
    throw UnimplementedError();
  }

  @override
  Future<SpotifyConnectionState> disconnect() async {
    throw UnimplementedError();
  }

  @override
  Future<String?> getValidAccessToken() async {
    return null;
  }

  @override
  Future<SpotifyConnectionState> restoreSession() async {
    throw UnimplementedError();
  }
}
