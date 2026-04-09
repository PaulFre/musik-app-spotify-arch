import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:party_queue_app/src/features/spotify/domain/models/spotify_connection_state.dart';
import 'package:party_queue_app/src/features/spotify/domain/models/spotify_playback_state.dart';
import 'package:party_queue_app/src/features/spotify/domain/spotify_auth_service.dart';
import 'package:party_queue_app/src/features/spotify/domain/spotify_playback_service.dart';

class SpotifyConnectionController extends ChangeNotifier {
  SpotifyConnectionController({
    required SpotifyAuthService authService,
    required SpotifyPlaybackService playbackService,
    Duration playbackPollInterval = const Duration(seconds: 3),
  }) : _authService = authService,
       _playbackService = playbackService,
       _playbackPollInterval = playbackPollInterval;

  final SpotifyAuthService _authService;
  final SpotifyPlaybackService _playbackService;
  final Duration _playbackPollInterval;

  SpotifyConnectionState _connectionState = const SpotifyConnectionState();
  SpotifyPlaybackState _playbackState = const SpotifyPlaybackState();
  bool _isLoading = false;
  Timer? _playbackPollTimer;
  int _refreshRequestId = 0;

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
    if (_connectionState.spotifyConnected &&
        _connectionState.premiumConfirmed) {
      await refreshDevices();
    }
    _syncPlaybackPolling();
    _setLoading(false);
  }

  Future<void> restoreSession() async {
    _setLoading(true);
    _connectionState = await _authService.restoreSession();
    if (_connectionState.spotifyConnected &&
        _connectionState.premiumConfirmed) {
      await refreshDevices();
    }
    _syncPlaybackPolling();
    _setLoading(false);
  }

  Future<void> disconnect() async {
    _setLoading(true);
    _stopPlaybackPolling();
    _connectionState = await _authService.disconnect();
    _playbackState = const SpotifyPlaybackState();
    _setLoading(false);
  }

  Future<void> refreshDevices() async {
    _playbackState = await _playbackService.loadAvailableDevices();
    _syncPlaybackPolling();
    notifyListeners();
  }

  Future<void> selectDevice(String deviceId) async {
    _setLoading(true);
    _playbackState = await _playbackService.selectDevice(deviceId);
    _syncPlaybackPolling();
    if (_playbackState.hasSelectedDevice) {
      await refreshPlaybackState();
    }
    _setLoading(false);
  }

  Future<void> refreshPlaybackState({bool fromPolling = false}) async {
    final requestId = ++_refreshRequestId;
    final nextState = await _playbackService.refreshPlaybackState();
    if (requestId != _refreshRequestId) {
      return;
    }
    _playbackState = nextState;
    _syncPlaybackPolling();
    notifyListeners();
  }

  void applyPlaybackState(SpotifyPlaybackState state) {
    _playbackState = state;
    _syncPlaybackPolling();
    notifyListeners();
  }

  void _syncPlaybackPolling() {
    final shouldPoll =
        _connectionState.spotifyConnected &&
        _connectionState.premiumConfirmed &&
        _playbackState.hasSelectedDevice;
    if (!shouldPoll) {
      _stopPlaybackPolling();
      return;
    }
    if (_playbackPollTimer != null) {
      return;
    }
    _playbackPollTimer = Timer.periodic(_playbackPollInterval, (_) {
      unawaited(refreshPlaybackState(fromPolling: true));
    });
  }

  void _stopPlaybackPolling() {
    _playbackPollTimer?.cancel();
    _playbackPollTimer = null;
  }

  void _setLoading(bool isLoading) {
    _isLoading = isLoading;
    notifyListeners();
  }

  @override
  void dispose() {
    _stopPlaybackPolling();
    super.dispose();
  }
}
