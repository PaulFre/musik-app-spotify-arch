import 'package:party_queue_app/src/features/spotify/domain/models/spotify_device.dart';

class SpotifyPlaybackState {
  const SpotifyPlaybackState({
    this.availableDevices = const <SpotifyDevice>[],
    this.selectedDeviceId,
    this.actualNowPlayingTrackId,
    this.actualIsPaused = true,
    this.lastCommand,
    this.playbackError,
    this.isBusy = false,
    this.lastSyncedAt,
  });

  final List<SpotifyDevice> availableDevices;
  final String? selectedDeviceId;
  final String? actualNowPlayingTrackId;
  final bool actualIsPaused;
  final String? lastCommand;
  final String? playbackError;
  final bool isBusy;
  final DateTime? lastSyncedAt;

  bool get hasSelectedDevice => selectedDeviceId != null;

  SpotifyPlaybackState copyWith({
    List<SpotifyDevice>? availableDevices,
    String? selectedDeviceId,
    String? actualNowPlayingTrackId,
    bool? actualIsPaused,
    String? lastCommand,
    String? playbackError,
    bool? isBusy,
    DateTime? lastSyncedAt,
  }) {
    return SpotifyPlaybackState(
      availableDevices: availableDevices ?? this.availableDevices,
      selectedDeviceId: selectedDeviceId ?? this.selectedDeviceId,
      actualNowPlayingTrackId:
          actualNowPlayingTrackId ?? this.actualNowPlayingTrackId,
      actualIsPaused: actualIsPaused ?? this.actualIsPaused,
      lastCommand: lastCommand ?? this.lastCommand,
      playbackError: playbackError,
      isBusy: isBusy ?? this.isBusy,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }
}
