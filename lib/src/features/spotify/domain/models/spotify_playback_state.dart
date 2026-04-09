import 'package:party_queue_app/src/features/spotify/domain/models/spotify_device.dart';

class SpotifyPlaybackState {
  static const Object _unset = Object();

  const SpotifyPlaybackState({
    this.availableDevices = const <SpotifyDevice>[],
    this.selectedDeviceId,
    this.actualNowPlayingTrackId,
    this.actualIsPaused = true,
    this.lastCommand,
    this.playbackErrorCode,
    this.playbackError,
    this.isBusy = false,
    this.lastSyncedAt,
  });

  final List<SpotifyDevice> availableDevices;
  final String? selectedDeviceId;
  final String? actualNowPlayingTrackId;
  final bool actualIsPaused;
  final String? lastCommand;
  final String? playbackErrorCode;
  final String? playbackError;
  final bool isBusy;
  final DateTime? lastSyncedAt;

  bool get hasSelectedDevice => selectedDeviceId != null;

  SpotifyPlaybackState copyWith({
    List<SpotifyDevice>? availableDevices,
    Object? selectedDeviceId = _unset,
    Object? actualNowPlayingTrackId = _unset,
    bool? actualIsPaused,
    Object? lastCommand = _unset,
    Object? playbackErrorCode = _unset,
    Object? playbackError = _unset,
    bool? isBusy,
    Object? lastSyncedAt = _unset,
  }) {
    return SpotifyPlaybackState(
      availableDevices: availableDevices ?? this.availableDevices,
      selectedDeviceId: selectedDeviceId == _unset
          ? this.selectedDeviceId
          : selectedDeviceId as String?,
      actualNowPlayingTrackId: actualNowPlayingTrackId == _unset
          ? this.actualNowPlayingTrackId
          : actualNowPlayingTrackId as String?,
      actualIsPaused: actualIsPaused ?? this.actualIsPaused,
      lastCommand: lastCommand == _unset ? this.lastCommand : lastCommand as String?,
      playbackErrorCode: playbackErrorCode == _unset
          ? this.playbackErrorCode
          : playbackErrorCode as String?,
      playbackError: playbackError == _unset
          ? this.playbackError
          : playbackError as String?,
      isBusy: isBusy ?? this.isBusy,
      lastSyncedAt: lastSyncedAt == _unset
          ? this.lastSyncedAt
          : lastSyncedAt as DateTime?,
    );
  }
}
