import 'dart:async';

import 'package:party_queue_app/src/features/party/data/party_room_repository.dart';
import 'package:party_queue_app/src/features/party/domain/models/party_room.dart';
import 'package:party_queue_app/src/features/party/domain/models/queue_item.dart';
import 'package:party_queue_app/src/features/party/domain/models/room_playback_intent.dart';
import 'package:party_queue_app/src/features/spotify/application/playback_orchestrator.dart';

class RoomPlaybackIntentProcessor {
  RoomPlaybackIntentProcessor({
    required PartyRoomRepository repository,
    required PlaybackOrchestrator playbackOrchestrator,
  }) : _repository = repository,
       _playbackOrchestrator = playbackOrchestrator;

  final PartyRoomRepository _repository;
  final PlaybackOrchestrator _playbackOrchestrator;

  StreamSubscription<PartyRoom?>? _roomSub;
  String? _activeCode;
  bool _isProcessing = false;
  bool _hasPendingPass = false;
  int? _lastObservedIntentVersion;

  void start(String code) {
    if (_activeCode == code && _roomSub != null) {
      return;
    }
    stop();
    _activeCode = code;
    _roomSub = _repository.watchRoom(code).listen((room) {
      if (room == null || room.isClosed) {
        _lastObservedIntentVersion = null;
        return;
      }
      if (room.playbackIntent.isNone) {
        _lastObservedIntentVersion = null;
        return;
      }
      if (_lastObservedIntentVersion == room.playbackIntentVersion) {
        return;
      }
      _lastObservedIntentVersion = room.playbackIntentVersion;
      _scheduleProcessing();
    });
  }

  void stop() {
    _roomSub?.cancel();
    _roomSub = null;
    _activeCode = null;
    _hasPendingPass = false;
    _isProcessing = false;
    _lastObservedIntentVersion = null;
  }

  void dispose() {
    stop();
  }

  void _scheduleProcessing() {
    if (_isProcessing) {
      _hasPendingPass = true;
      return;
    }
    unawaited(_drainQueue());
  }

  Future<void> _drainQueue() async {
    final code = _activeCode;
    if (code == null) {
      return;
    }
    _isProcessing = true;
    try {
      do {
        _hasPendingPass = false;
        final room = _repository.readRoom(code);
        if (room == null || room.isClosed || room.playbackIntent.isNone) {
          continue;
        }
        await _processRoom(room);
      } while (_hasPendingPass);
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> _processRoom(PartyRoom room) async {
    switch (room.playbackIntent.type) {
      case RoomPlaybackIntentType.playTrack:
        await _processPlayTrack(room);
        return;
      case RoomPlaybackIntentType.pause:
        await _processPause(room);
        return;
      case RoomPlaybackIntentType.resume:
        await _processResume(room);
        return;
      case RoomPlaybackIntentType.skip:
        await _processSkip(room);
        return;
      case RoomPlaybackIntentType.none:
      case RoomPlaybackIntentType.closeRoom:
        return;
    }
  }

  Future<void> _processPlayTrack(PartyRoom room) async {
    final intent = room.playbackIntent;
    final intentVersion = room.playbackIntentVersion;
    final trackId = intent.trackId;
    if (trackId == null) {
      await _clearIntentWithError(
        room.code,
        intent,
        intentVersion,
        'Kein Track fuer Playback ausgewaehlt.',
      );
      return;
    }

    QueueItem? queueItem;
    for (final item in room.queue) {
      if (item.track.id == trackId) {
        queueItem = item;
        break;
      }
    }
    if (queueItem == null) {
      await _clearIntentWithError(
        room.code,
        intent,
        intentVersion,
        'Der angeforderte Song ist nicht mehr in der Queue.',
      );
      return;
    }

    final result = await _playbackOrchestrator.playTrack(queueItem.track);
    if (!result.success) {
      await _clearIntentWithError(
        room.code,
        intent,
        intentVersion,
        result.errorMessage ?? 'Playback konnte nicht gestartet werden.',
      );
      return;
    }

    final latestRoom = _repository.readRoom(room.code);
    if (latestRoom == null || !_sameIntent(latestRoom, room)) {
      _hasPendingPass = true;
      return;
    }

    final confirmedRoom = _buildConfirmedPlayRoom(
      latestRoom,
      queueItem: queueItem,
      trackId: trackId,
    );
    await _repository.saveRoom(confirmedRoom);
  }

  Future<void> _clearIntentWithError(
    String roomCode,
    RoomPlaybackIntent intent,
    int intentVersion,
    String message,
  ) async {
    final latestRoom = _repository.readRoom(roomCode);
    if (latestRoom == null ||
        !_matchesExpectedIntent(latestRoom, intent, intentVersion)) {
      _hasPendingPass = true;
      return;
    }
    await _repository.saveRoom(
      latestRoom.copyWith(
        playbackIntent: const RoomPlaybackIntent.none(),
        playbackErrorMessage: message,
      ),
    );
  }

  Future<void> _processPause(PartyRoom room) async {
    final intent = room.playbackIntent;
    final intentVersion = room.playbackIntentVersion;
    final result = await _playbackOrchestrator.pause();
    if (!result.success) {
      await _clearIntentWithError(
        room.code,
        intent,
        intentVersion,
        result.errorMessage ?? 'Playback konnte nicht pausiert werden.',
      );
      return;
    }
    await _confirmSimpleIntent(
      room.code,
      intent,
      intentVersion,
      (latestRoom) => latestRoom.copyWith(
        playbackIntent: const RoomPlaybackIntent.none(),
        isPaused: true,
        playbackErrorMessage: null,
      ),
    );
  }

  Future<void> _processResume(PartyRoom room) async {
    final intent = room.playbackIntent;
    final intentVersion = room.playbackIntentVersion;
    final result = await _playbackOrchestrator.resume();
    if (!result.success) {
      await _clearIntentWithError(
        room.code,
        intent,
        intentVersion,
        result.errorMessage ?? 'Playback konnte nicht fortgesetzt werden.',
      );
      return;
    }
    await _confirmSimpleIntent(
      room.code,
      intent,
      intentVersion,
      (latestRoom) => latestRoom.copyWith(
        playbackIntent: const RoomPlaybackIntent.none(),
        isPaused: false,
        playbackErrorMessage: null,
      ),
    );
  }

  Future<void> _processSkip(PartyRoom room) async {
    final intent = room.playbackIntent;
    final intentVersion = room.playbackIntentVersion;
    final result = await _playbackOrchestrator.skip();
    if (!result.success) {
      await _clearIntentWithError(
        room.code,
        intent,
        intentVersion,
        result.errorMessage ?? 'Playback konnte nicht uebersprungen werden.',
      );
      return;
    }

    final latestRoom = _repository.readRoom(room.code);
    if (latestRoom == null || !_sameIntent(latestRoom, room)) {
      _hasPendingPass = true;
      return;
    }

    final nextTrack = _nextPlayableQueueItem(latestRoom);
    if (nextTrack == null) {
      await _repository.saveRoom(
        latestRoom.copyWith(
          playbackIntent: const RoomPlaybackIntent.none(),
          playbackIntentVersion: latestRoom.playbackIntentVersion,
          desiredNowPlayingTrackId: null,
          nowPlayingTrack: null,
          nowPlayingTrackId: null,
          isPaused: false,
          playbackErrorMessage: null,
        ),
      );
      return;
    }

    await _repository.saveRoom(
      latestRoom.copyWith(
        playbackIntent: RoomPlaybackIntent.playTrack(nextTrack.track.id),
        playbackIntentVersion: latestRoom.playbackIntentVersion + 1,
        desiredNowPlayingTrackId: nextTrack.track.id,
        nowPlayingTrack: null,
        nowPlayingTrackId: null,
        isPaused: false,
        playbackErrorMessage: null,
      ),
    );
  }

  Future<void> _confirmSimpleIntent(
    String roomCode,
    RoomPlaybackIntent intent,
    int intentVersion,
    PartyRoom Function(PartyRoom room) update,
  ) async {
    final latestRoom = _repository.readRoom(roomCode);
    if (latestRoom == null ||
        !_matchesExpectedIntent(latestRoom, intent, intentVersion)) {
      _hasPendingPass = true;
      return;
    }
    await _repository.saveRoom(update(latestRoom));
  }

  PartyRoom _buildConfirmedPlayRoom(
    PartyRoom room, {
    required QueueItem queueItem,
    required String trackId,
  }) {
    final cooldownUntil = DateTime.now().add(
      Duration(minutes: room.settings.cooldownMinutes),
    );
    final updatedCooldown = Map<String, DateTime>.from(room.cooldownByTrackId)
      ..[trackId] = cooldownUntil;
    final updatedQueue = List<QueueItem>.from(room.queue)
      ..removeWhere((item) => item.track.id == trackId);

    return room.copyWith(
      desiredNowPlayingTrackId: null,
      playbackIntent: const RoomPlaybackIntent.none(),
      nowPlayingTrack: queueItem.track,
      nowPlayingTrackId: trackId,
      queue: updatedQueue,
      cooldownByTrackId: updatedCooldown,
      isPaused: false,
      playbackErrorMessage: null,
    );
  }

  bool _sameIntent(PartyRoom latestRoom, PartyRoom intentRoom) {
    return latestRoom.playbackIntentVersion ==
            intentRoom.playbackIntentVersion &&
        latestRoom.playbackIntent.type == intentRoom.playbackIntent.type &&
        latestRoom.playbackIntent.trackId == intentRoom.playbackIntent.trackId;
  }

  bool _matchesExpectedIntent(
    PartyRoom room,
    RoomPlaybackIntent intent,
    int intentVersion,
  ) {
    return room.playbackIntentVersion == intentVersion &&
        room.playbackIntent.type == intent.type &&
        room.playbackIntent.trackId == intent.trackId;
  }

  QueueItem? _nextPlayableQueueItem(PartyRoom room) {
    for (final item in room.queue) {
      final cooldownUntil = room.cooldownByTrackId[item.track.id];
      if (cooldownUntil == null || !DateTime.now().isBefore(cooldownUntil)) {
        return item;
      }
    }
    return null;
  }
}
