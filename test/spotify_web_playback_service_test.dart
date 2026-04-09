import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:party_queue_app/src/features/party/domain/models/spotify_track.dart';
import 'package:party_queue_app/src/features/spotify/data/spotify_app_config.dart';
import 'package:party_queue_app/src/features/spotify/data/spotify_web_playback_service.dart';
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

  test(
    'loadAvailableDevices resolves Spotify devices into playback state',
    () async {
      final service = SpotifyWebPlaybackService(
        config: config,
        authService: StaticTokenAuthService(),
        httpClient: MockClient((request) async {
          expect(
            request.url.toString(),
            '${config.apiBaseUrl}/me/player/devices',
          );
          return http.Response(
            jsonEncode(<String, Object>{
              'devices': <Map<String, Object>>[
                <String, Object>{
                  'id': 'device-speaker',
                  'name': 'Wohnzimmer Speaker',
                  'type': 'speaker',
                  'is_active': false,
                },
                <String, Object>{
                  'id': 'device-browser',
                  'name': 'Browser Player',
                  'type': 'computer',
                  'is_active': true,
                },
              ],
            }),
            200,
          );
        }),
        now: () => DateTime(2026, 4, 9, 15),
      );

      final state = await service.loadAvailableDevices();

      expect(state.availableDevices, hasLength(2));
      expect(state.selectedDeviceId, 'device-browser');
      expect(
        state.availableDevices.where((device) => device.isActive),
        hasLength(1),
      );
      expect(state.playbackErrorCode, isNull);
      expect(state.playbackError, isNull);
    },
  );

  test(
    'selectDevice sets selectedDeviceId after successful transfer',
    () async {
      final requests = <String>[];
      final service = SpotifyWebPlaybackService(
        config: config,
        authService: StaticTokenAuthService(),
        httpClient: MockClient((request) async {
          requests.add('${request.method} ${request.url}');
          if (request.method == 'GET') {
            return http.Response(
              jsonEncode(<String, Object>{
                'devices': <Map<String, Object>>[
                  <String, Object>{
                    'id': 'device-speaker',
                    'name': 'Wohnzimmer Speaker',
                    'type': 'speaker',
                    'is_active': false,
                  },
                ],
              }),
              200,
            );
          }

          expect(request.url.toString(), '${config.apiBaseUrl}/me/player');
          expect(jsonDecode(request.body), <String, Object>{
            'device_ids': <String>['device-speaker'],
            'play': false,
          });
          return http.Response('', 204);
        }),
      );

      await service.loadAvailableDevices();
      final state = await service.selectDevice('device-speaker');

      expect(requests, contains('PUT ${config.apiBaseUrl}/me/player'));
      expect(state.selectedDeviceId, 'device-speaker');
      expect(state.availableDevices.single.isActive, isTrue);
      expect(state.playbackErrorCode, isNull);
    },
  );

  test(
    'loadAvailableDevices clears stale selection when device disappears',
    () async {
      var getCalls = 0;
      final service = SpotifyWebPlaybackService(
        config: config,
        authService: StaticTokenAuthService(),
        httpClient: MockClient((request) async {
          if (request.method == 'PUT') {
            return http.Response('', 204);
          }
          getCalls += 1;
          return http.Response(
            jsonEncode(
              getCalls == 1
                  ? <String, Object>{
                      'devices': <Map<String, Object>>[
                        <String, Object>{
                          'id': 'device-speaker',
                          'name': 'Wohnzimmer Speaker',
                          'type': 'speaker',
                          'is_active': false,
                        },
                      ],
                    }
                  : <String, Object>{
                      'devices': <Map<String, Object>>[
                        <String, Object>{
                          'id': 'device-browser',
                          'name': 'Browser Player',
                          'type': 'computer',
                          'is_active': false,
                        },
                      ],
                    },
            ),
            200,
          );
        }),
      );

      await service.loadAvailableDevices();
      await service.selectDevice('device-speaker');
      final state = await service.loadAvailableDevices();

      expect(state.selectedDeviceId, isNull);
      expect(state.playbackErrorCode, 'device-unavailable');
      expect(
        state.playbackError,
        'Das zuvor ausgewaehlte Geraet ist nicht mehr verfuegbar.',
      );
    },
  );

  test('playTrack sends real Spotify play command for selected device', () async {
    final requests = <String>[];
    final service = SpotifyWebPlaybackService(
      config: config,
      authService: StaticTokenAuthService(),
      httpClient: MockClient((request) async {
        requests.add('${request.method} ${request.url}');
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode(<String, Object>{
              'devices': <Map<String, Object>>[
                <String, Object>{
                  'id': 'device-speaker',
                  'name': 'Wohnzimmer Speaker',
                  'type': 'speaker',
                  'is_active': false,
                },
              ],
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/me/player') && request.url.queryParameters.isEmpty) {
          expect(jsonDecode(request.body), <String, Object>{
            'device_ids': <String>['device-speaker'],
            'play': false,
          });
          return http.Response('', 204);
        }
        expect(request.url.queryParameters['device_id'], 'device-speaker');
        expect(jsonDecode(request.body), <String, Object>{
          'uris': <String>['spotify:track:track-1'],
        });
        return http.Response('', 204);
      }),
    );

    await service.loadAvailableDevices();
    await service.selectDevice('device-speaker');
    final result = await service.playTrack(
      const SpotifyTrack(
        id: 'track-1',
        uri: 'spotify:track:track-1',
        title: 'Track 1',
        artist: 'Artist 1',
      ),
    );

    expect(
      requests,
      contains('PUT ${config.apiBaseUrl}/me/player/play?device_id=device-speaker'),
    );
    expect(result.success, isTrue);
    expect(result.effectiveTrackId, 'track-1');
  });

  test('pause, resume and skip send Spotify commands', () async {
    final requests = <String>[];
    final service = SpotifyWebPlaybackService(
      config: config,
      authService: StaticTokenAuthService(),
      httpClient: MockClient((request) async {
        requests.add('${request.method} ${request.url}');
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode(<String, Object>{
              'devices': <Map<String, Object>>[
                <String, Object>{
                  'id': 'device-speaker',
                  'name': 'Wohnzimmer Speaker',
                  'type': 'speaker',
                  'is_active': false,
                },
              ],
            }),
            200,
          );
        }
        return http.Response('', request.method == 'POST' ? 204 : 204);
      }),
    );

    await service.loadAvailableDevices();
    await service.selectDevice('device-speaker');

    expect((await service.pause()).success, isTrue);
    expect((await service.resume()).success, isTrue);
    expect((await service.skip()).success, isTrue);

    expect(
      requests,
      contains('PUT ${config.apiBaseUrl}/me/player/pause?device_id=device-speaker'),
    );
    expect(
      requests,
      contains('PUT ${config.apiBaseUrl}/me/player/play?device_id=device-speaker'),
    );
    expect(
      requests,
      contains('POST ${config.apiBaseUrl}/me/player/next?device_id=device-speaker'),
    );
  });

  test('refreshPlaybackState mirrors actual Spotify playback state', () async {
    final service = SpotifyWebPlaybackService(
      config: config,
      authService: StaticTokenAuthService(),
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/devices')) {
          return http.Response(
            jsonEncode(<String, Object>{
              'devices': <Map<String, Object>>[
                <String, Object>{
                  'id': 'device-speaker',
                  'name': 'Wohnzimmer Speaker',
                  'type': 'speaker',
                  'is_active': false,
                },
              ],
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode(<String, Object>{
            'device': <String, Object>{
              'id': 'device-speaker',
              'name': 'Wohnzimmer Speaker',
              'type': 'speaker',
              'is_active': true,
            },
            'is_playing': true,
            'item': <String, Object>{
              'id': 'track-42',
            },
          }),
          200,
        );
      }),
    );

    await service.loadAvailableDevices();
    final state = await service.refreshPlaybackState();

    expect(state.selectedDeviceId, 'device-speaker');
    expect(state.actualNowPlayingTrackId, 'track-42');
    expect(state.actualIsPaused, isFalse);
    expect(state.availableDevices.single.isActive, isTrue);
    expect(state.playbackError, isNull);
  });

  test('playTrack fails cleanly when selected device vanished', () async {
    final service = SpotifyWebPlaybackService(
      config: config,
      authService: StaticTokenAuthService(),
      httpClient: MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode(<String, Object>{
              'devices': <Map<String, Object>>[
                <String, Object>{
                  'id': 'device-speaker',
                  'name': 'Wohnzimmer Speaker',
                  'type': 'speaker',
                  'is_active': false,
                },
              ],
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/me/player') && request.url.queryParameters.isEmpty) {
          return http.Response('', 204);
        }
        return http.Response('', 404);
      }),
    );

    await service.loadAvailableDevices();
    await service.selectDevice('device-speaker');
    final result = await service.playTrack(
      const SpotifyTrack(
        id: 'track-1',
        uri: 'spotify:track:track-1',
        title: 'Track 1',
        artist: 'Artist 1',
      ),
    );
    final state = await service.refreshPlaybackState();

    expect(result.success, isFalse);
    expect(result.errorCode, 'device-unavailable');
    expect(state.selectedDeviceId, isNull);
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
