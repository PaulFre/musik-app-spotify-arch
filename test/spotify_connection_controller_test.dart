import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:party_queue_app/src/features/spotify/application/spotify_connection_controller.dart';
import 'package:party_queue_app/src/features/spotify/domain/models/playback_command_result.dart';
import 'package:party_queue_app/src/features/spotify/domain/models/spotify_connection_state.dart';
import 'package:party_queue_app/src/features/spotify/domain/models/spotify_device.dart';
import 'package:party_queue_app/src/features/spotify/domain/models/spotify_playback_state.dart';
import 'package:party_queue_app/src/features/spotify/domain/spotify_auth_service.dart';
import 'package:party_queue_app/src/features/spotify/domain/spotify_playback_service.dart';
import 'package:party_queue_app/src/features/party/domain/models/spotify_track.dart';

void main() {
  test(
    'connectHost does not refresh devices when premium is missing',
    () async {
      final playbackService = CountingPlaybackService();
      final controller = SpotifyConnectionController(
        authService: NonPremiumAuthService(),
        playbackService: playbackService,
      );

      await controller.connectHost();

      expect(controller.connectionState.spotifyConnected, isTrue);
      expect(controller.connectionState.premiumConfirmed, isFalse);
      expect(controller.connectionState.errorCode, 'spotify-premium-required');
      expect(playbackService.loadAvailableDevicesCallCount, 0);
      expect(controller.playbackState.availableDevices, isEmpty);
    },
  );

  test('controller polls playback state while ready and stops after disconnect', () async {
    final playbackService = PollingPlaybackService();
    final controller = SpotifyConnectionController(
      authService: ReadyAuthService(),
      playbackService: playbackService,
      playbackPollInterval: const Duration(milliseconds: 20),
    );

    await controller.connectHost();
    await Future<void>.delayed(const Duration(milliseconds: 75));

    expect(
      playbackService.refreshPlaybackStateCallCount,
      greaterThanOrEqualTo(2),
    );

    final callsBeforeDisconnect = playbackService.refreshPlaybackStateCallCount;
    await controller.disconnect();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(
      playbackService.refreshPlaybackStateCallCount,
      callsBeforeDisconnect,
    );
  });

  test(
    'older playback refresh result does not overwrite a newer confirmed state',
    () async {
      final playbackService = SequencedRefreshPlaybackService();
      final controller = SpotifyConnectionController(
        authService: ReadyAuthService(),
        playbackService: playbackService,
        playbackPollInterval: const Duration(seconds: 10),
      );

      controller.applyPlaybackState(
        const SpotifyPlaybackState(
          selectedDeviceId: 'device-speaker',
          availableDevices: <SpotifyDevice>[
            SpotifyDevice(
              id: 'device-speaker',
              name: 'Wohnzimmer Speaker',
              type: 'speaker',
              isActive: true,
            ),
          ],
        ),
      );

      final olderPoll = controller.refreshPlaybackState(fromPolling: true);
      final newerRefresh = controller.refreshPlaybackState();

      playbackService.completeRefresh(
        1,
        const SpotifyPlaybackState(
          selectedDeviceId: 'device-speaker',
          actualNowPlayingTrackId: 'track-new',
        ),
      );
      await newerRefresh;

      playbackService.completeRefresh(
        0,
        const SpotifyPlaybackState(
          selectedDeviceId: 'device-speaker',
          actualNowPlayingTrackId: 'track-old',
        ),
      );
      await olderPoll;

      expect(controller.playbackState.actualNowPlayingTrackId, 'track-new');
    },
  );
}

class NonPremiumAuthService implements SpotifyAuthService {
  @override
  Future<SpotifyConnectionState> connect() async {
    return const SpotifyConnectionState(
      spotifyConnected: true,
      spotifyUserId: 'spotify-host-free',
      displayName: 'Free Host',
      accountProduct: 'free',
      premiumConfirmed: false,
      errorCode: 'spotify-premium-required',
      errorMessage: 'Spotify Premium ist fuer den Host erforderlich.',
    );
  }

  @override
  Future<SpotifyConnectionState> disconnect() async {
    return const SpotifyConnectionState();
  }

  @override
  Future<String?> getValidAccessToken() async {
    return 'token';
  }

  @override
  Future<SpotifyConnectionState> restoreSession() async {
    return connect();
  }
}

class ReadyAuthService implements SpotifyAuthService {
  @override
  Future<SpotifyConnectionState> connect() async {
    return const SpotifyConnectionState(
      spotifyConnected: true,
      spotifyUserId: 'spotify-host-1',
      displayName: 'Host',
      accountProduct: 'premium',
      premiumConfirmed: true,
    );
  }

  @override
  Future<SpotifyConnectionState> disconnect() async {
    return const SpotifyConnectionState();
  }

  @override
  Future<String?> getValidAccessToken() async {
    return 'token';
  }

  @override
  Future<SpotifyConnectionState> restoreSession() async {
    return connect();
  }
}

class CountingPlaybackService implements SpotifyPlaybackService {
  int loadAvailableDevicesCallCount = 0;

  @override
  Future<SpotifyPlaybackState> loadAvailableDevices() async {
    loadAvailableDevicesCallCount += 1;
    return const SpotifyPlaybackState();
  }

  @override
  Future<PlaybackCommandResult> pause() async {
    throw UnimplementedError();
  }

  @override
  Future<PlaybackCommandResult> playTrack(SpotifyTrack track) async {
    throw UnimplementedError();
  }

  @override
  Future<SpotifyPlaybackState> refreshPlaybackState() async {
    throw UnimplementedError();
  }

  @override
  Future<PlaybackCommandResult> resume() async {
    throw UnimplementedError();
  }

  @override
  Future<SpotifyPlaybackState> selectDevice(String deviceId) async {
    throw UnimplementedError();
  }

  @override
  Future<PlaybackCommandResult> skip() async {
    throw UnimplementedError();
  }
}

class PollingPlaybackService implements SpotifyPlaybackService {
  int refreshPlaybackStateCallCount = 0;

  @override
  Future<SpotifyPlaybackState> loadAvailableDevices() async {
    return const SpotifyPlaybackState(
      selectedDeviceId: 'device-speaker',
      availableDevices: <SpotifyDevice>[
        SpotifyDevice(
          id: 'device-speaker',
          name: 'Wohnzimmer Speaker',
          type: 'speaker',
          isActive: true,
        ),
      ],
    );
  }

  @override
  Future<PlaybackCommandResult> pause() async {
    throw UnimplementedError();
  }

  @override
  Future<PlaybackCommandResult> playTrack(SpotifyTrack track) async {
    throw UnimplementedError();
  }

  @override
  Future<SpotifyPlaybackState> refreshPlaybackState() async {
    refreshPlaybackStateCallCount += 1;
    return SpotifyPlaybackState(
      selectedDeviceId: 'device-speaker',
      availableDevices: const <SpotifyDevice>[
        SpotifyDevice(
          id: 'device-speaker',
          name: 'Wohnzimmer Speaker',
          type: 'speaker',
          isActive: true,
        ),
      ],
      actualNowPlayingTrackId: 'track-$refreshPlaybackStateCallCount',
    );
  }

  @override
  Future<PlaybackCommandResult> resume() async {
    throw UnimplementedError();
  }

  @override
  Future<SpotifyPlaybackState> selectDevice(String deviceId) async {
    throw UnimplementedError();
  }

  @override
  Future<PlaybackCommandResult> skip() async {
    throw UnimplementedError();
  }
}

class SequencedRefreshPlaybackService implements SpotifyPlaybackService {
  final List<Completer<SpotifyPlaybackState>> _refreshCompleters =
      <Completer<SpotifyPlaybackState>>[];

  void completeRefresh(int index, SpotifyPlaybackState state) {
    _refreshCompleters[index].complete(state);
  }

  @override
  Future<SpotifyPlaybackState> loadAvailableDevices() async {
    return const SpotifyPlaybackState();
  }

  @override
  Future<PlaybackCommandResult> pause() async {
    throw UnimplementedError();
  }

  @override
  Future<PlaybackCommandResult> playTrack(SpotifyTrack track) async {
    throw UnimplementedError();
  }

  @override
  Future<SpotifyPlaybackState> refreshPlaybackState() {
    final completer = Completer<SpotifyPlaybackState>();
    _refreshCompleters.add(completer);
    return completer.future;
  }

  @override
  Future<PlaybackCommandResult> resume() async {
    throw UnimplementedError();
  }

  @override
  Future<SpotifyPlaybackState> selectDevice(String deviceId) async {
    throw UnimplementedError();
  }

  @override
  Future<PlaybackCommandResult> skip() async {
    throw UnimplementedError();
  }
}
