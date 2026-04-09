import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:party_queue_app/src/features/party/domain/models/spotify_track.dart';
import 'package:party_queue_app/src/features/spotify/application/spotify_connection_controller.dart';
import 'package:party_queue_app/src/features/spotify/domain/models/playback_command_result.dart';

class PlaybackOrchestrator extends ChangeNotifier {
  PlaybackOrchestrator({
    required SpotifyConnectionController connectionController,
  }) : _connectionController = connectionController {
    _connectionController.addListener(notifyListeners);
  }

  final SpotifyConnectionController _connectionController;
  Future<void> _queue = Future<void>.value();

  String? _lastError;

  String? get lastError => _lastError;

  bool get canControlPlayback => _connectionController.isReadyForPlayback;

  Future<PlaybackCommandResult> playTrack(SpotifyTrack track) {
    return _runSerial(() async {
      final gate = _validateReady();
      if (gate != null) {
        return gate;
      }
      final result = await _connectionController.playbackService.playTrack(
        track,
      );
      await _syncResult(result);
      return result;
    });
  }

  Future<PlaybackCommandResult> pause() {
    return _runSerial(() async {
      final gate = _validateReady();
      if (gate != null) {
        return gate;
      }
      final result = await _connectionController.playbackService.pause();
      await _syncResult(result);
      return result;
    });
  }

  Future<PlaybackCommandResult> resume() {
    return _runSerial(() async {
      final gate = _validateReady();
      if (gate != null) {
        return gate;
      }
      final result = await _connectionController.playbackService.resume();
      await _syncResult(result);
      return result;
    });
  }

  Future<PlaybackCommandResult> skip() {
    return _runSerial(() async {
      final gate = _validateReady();
      if (gate != null) {
        return gate;
      }
      final result = await _connectionController.playbackService.skip();
      await _syncResult(result);
      return result;
    });
  }

  PlaybackCommandResult? _validateReady() {
    final connectionState = _connectionController.connectionState;
    if (!connectionState.spotifyConnected) {
      return const PlaybackCommandResult.failure(
        errorCode: 'spotify-not-connected',
        errorMessage: 'Spotify ist nicht verbunden.',
      );
    }
    if (!connectionState.premiumConfirmed) {
      return const PlaybackCommandResult.failure(
        errorCode: 'premium-required',
        errorMessage: 'Spotify Premium ist fuer Playback erforderlich.',
      );
    }
    if (!_connectionController.playbackState.hasSelectedDevice) {
      return const PlaybackCommandResult.failure(
        errorCode: 'no-device',
        errorMessage: 'Bitte zuerst ein Wiedergabegeraet auswaehlen.',
      );
    }
    return null;
  }

  Future<PlaybackCommandResult> _runSerial(
    Future<PlaybackCommandResult> Function() operation,
  ) {
    final completer = Completer<PlaybackCommandResult>();
    _queue = _queue.then((_) async {
      try {
        completer.complete(await operation());
      } catch (error) {
        completer.complete(
          PlaybackCommandResult.failure(
            errorCode: 'unexpected-error',
            errorMessage: '$error',
          ),
        );
      }
    });
    return completer.future;
  }

  Future<void> _syncResult(PlaybackCommandResult result) async {
    _lastError = result.errorMessage;
    await _connectionController.refreshPlaybackState();
    notifyListeners();
  }

  @override
  void dispose() {
    _connectionController.removeListener(notifyListeners);
    super.dispose();
  }
}
