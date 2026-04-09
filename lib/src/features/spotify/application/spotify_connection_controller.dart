import 'package:flutter/foundation.dart';
import 'package:party_queue_app/src/features/spotify/domain/models/spotify_connection_state.dart';
import 'package:party_queue_app/src/features/spotify/domain/models/spotify_playback_state.dart';
import 'package:party_queue_app/src/features/spotify/domain/spotify_auth_service.dart';
import 'package:party_queue_app/src/features/spotify/domain/spotify_playback_service.dart';

class SpotifyConnectionController extends ChangeNotifier {
  SpotifyConnectionController({
    required SpotifyAuthService authService,
    required SpotifyPlaybackService playbackService,
  }) : _authService = authService,
       _playbackService = playbackService;

  final SpotifyAuthService _authService;
  final SpotifyPlaybackService _playbackService;

  SpotifyConnectionState _connectionState = const SpotifyConnectionState();
  SpotifyPlaybackState _playbackState = const SpotifyPlaybackState();
  bool _isLoading = false;

  SpotifyConnectionState get connectionState => _connectionState;
  SpotifyPlaybackState get playbackState => _playbackState;
  SpotifyPlaybackService get playbackService => _playbackService;
  bool get isLoading => _isLoading;
  bool get isReadyForPlayback =>
      _connectionState.spotifyConnected &&
      _connectionState.premiumConfirmed &&
      _playbackState.hasSelectedDevice;

  Future<void> connectHost() async {
    _setLoading(true);
    _connectionState = await _authService.connect();
    if (_connectionState.spotifyConnected && _connectionState.premiumConfirmed) {
      await refreshDevices();
    }
    _setLoading(false);
  }

  Future<void> restoreSession() async {
    _setLoading(true);
    _connectionState = await _authService.restoreSession();
    if (_connectionState.spotifyConnected && _connectionState.premiumConfirmed) {
      await refreshDevices();
    }
    _setLoading(false);
  }

  Future<void> disconnect() async {
    _setLoading(true);
    _connectionState = await _authService.disconnect();
    _playbackState = const SpotifyPlaybackState();
    _setLoading(false);
  }

  Future<void> refreshDevices() async {
    final devices = await _playbackService.loadAvailableDevices();
    _playbackState = _playbackState.copyWith(
      availableDevices: devices,
      playbackError: null,
      lastSyncedAt: DateTime.now(),
    );
    notifyListeners();
  }

  Future<void> selectDevice(String deviceId) async {
    _setLoading(true);
    _playbackState = await _playbackService.selectDevice(deviceId);
    _setLoading(false);
  }

  Future<void> refreshPlaybackState() async {
    _playbackState = await _playbackService.refreshPlaybackState();
    notifyListeners();
  }

  void applyPlaybackState(SpotifyPlaybackState state) {
    _playbackState = state;
    notifyListeners();
  }

  void _setLoading(bool isLoading) {
    _isLoading = isLoading;
    notifyListeners();
  }
}
