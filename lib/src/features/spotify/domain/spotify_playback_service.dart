import 'package:party_queue_app/src/features/party/domain/models/spotify_track.dart';
import 'package:party_queue_app/src/features/spotify/domain/models/playback_command_result.dart';
import 'package:party_queue_app/src/features/spotify/domain/models/spotify_device.dart';
import 'package:party_queue_app/src/features/spotify/domain/models/spotify_playback_state.dart';

abstract class SpotifyPlaybackService {
  Future<SpotifyPlaybackState> loadAvailableDevices();

  Future<SpotifyPlaybackState> selectDevice(String deviceId);

  Future<PlaybackCommandResult> playTrack(SpotifyTrack track);

  Future<PlaybackCommandResult> pause();

  Future<PlaybackCommandResult> resume();

  Future<PlaybackCommandResult> skip();

  Future<SpotifyPlaybackState> refreshPlaybackState();
}

class FakeSpotifyPlaybackService implements SpotifyPlaybackService {
  static const List<SpotifyDevice> _devices = <SpotifyDevice>[
    SpotifyDevice(
      id: 'device-speaker',
      name: 'Wohnzimmer Speaker',
      type: 'speaker',
    ),
    SpotifyDevice(
      id: 'device-browser',
      name: 'Browser Player',
      type: 'computer',
    ),
  ];

  SpotifyPlaybackState _state = const SpotifyPlaybackState(
    availableDevices: _devices,
  );

  @override
  Future<SpotifyPlaybackState> loadAvailableDevices() async {
    _state = _state.copyWith(
      availableDevices: _devices,
      selectedDeviceId: null,
      playbackErrorCode: null,
      lastSyncedAt: DateTime.now(),
      playbackError: null,
    );
    return _state;
  }

  @override
  Future<SpotifyPlaybackState> selectDevice(String deviceId) async {
    _state = _state.copyWith(
      availableDevices: _devices
          .map((device) => device.copyWith(isActive: device.id == deviceId))
          .toList(),
      selectedDeviceId: deviceId,
      playbackErrorCode: null,
      lastSyncedAt: DateTime.now(),
      playbackError: null,
    );
    return _state;
  }

  @override
  Future<PlaybackCommandResult> playTrack(SpotifyTrack track) async {
    if (_state.selectedDeviceId == null) {
      return const PlaybackCommandResult.failure(
        errorCode: 'no-device',
        errorMessage: 'Kein aktives Wiedergabegeraet ausgewaehlt.',
      );
    }
    _state = _state.copyWith(
      actualNowPlayingTrackId: track.id,
      actualIsPaused: false,
      lastCommand: 'play',
      playbackErrorCode: null,
      lastSyncedAt: DateTime.now(),
      playbackError: null,
    );
    return PlaybackCommandResult.success(
      effectiveTrackId: track.id,
      effectiveDeviceId: _state.selectedDeviceId,
    );
  }

  @override
  Future<PlaybackCommandResult> pause() async {
    if (_state.selectedDeviceId == null) {
      return const PlaybackCommandResult.failure(
        errorCode: 'no-device',
        errorMessage: 'Kein aktives Wiedergabegeraet ausgewaehlt.',
      );
    }
    _state = _state.copyWith(
      actualIsPaused: true,
      lastCommand: 'pause',
      playbackErrorCode: null,
      lastSyncedAt: DateTime.now(),
      playbackError: null,
    );
    return PlaybackCommandResult.success(
      effectiveTrackId: _state.actualNowPlayingTrackId,
      effectiveDeviceId: _state.selectedDeviceId,
    );
  }

  @override
  Future<SpotifyPlaybackState> refreshPlaybackState() async {
    _state = _state.copyWith(
      playbackErrorCode: null,
      lastSyncedAt: DateTime.now(),
      playbackError: null,
    );
    return _state;
  }

  @override
  Future<PlaybackCommandResult> resume() async {
    if (_state.selectedDeviceId == null) {
      return const PlaybackCommandResult.failure(
        errorCode: 'no-device',
        errorMessage: 'Kein aktives Wiedergabegeraet ausgewaehlt.',
      );
    }
    _state = _state.copyWith(
      actualIsPaused: false,
      lastCommand: 'resume',
      playbackErrorCode: null,
      lastSyncedAt: DateTime.now(),
      playbackError: null,
    );
    return PlaybackCommandResult.success(
      effectiveTrackId: _state.actualNowPlayingTrackId,
      effectiveDeviceId: _state.selectedDeviceId,
    );
  }

  @override
  Future<PlaybackCommandResult> skip() async {
    if (_state.selectedDeviceId == null) {
      return const PlaybackCommandResult.failure(
        errorCode: 'no-device',
        errorMessage: 'Kein aktives Wiedergabegeraet ausgewaehlt.',
      );
    }
    _state = _state.copyWith(
      actualIsPaused: false,
      lastCommand: 'skip',
      playbackErrorCode: null,
      lastSyncedAt: DateTime.now(),
      playbackError: null,
    );
    return PlaybackCommandResult.success(
      effectiveTrackId: _state.actualNowPlayingTrackId,
      effectiveDeviceId: _state.selectedDeviceId,
    );
  }
}
