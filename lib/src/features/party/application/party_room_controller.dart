import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:party_queue_app/src/core/utils/code_generator.dart';
import 'package:party_queue_app/src/features/party/data/party_room_repository.dart';
import 'package:party_queue_app/src/features/party/domain/models/party_room.dart';
import 'package:party_queue_app/src/features/party/domain/models/queue_item.dart';
import 'package:party_queue_app/src/features/party/domain/models/room_playback_intent.dart';
import 'package:party_queue_app/src/features/party/domain/models/room_settings.dart';
import 'package:party_queue_app/src/features/party/domain/models/spotify_track.dart';
import 'package:party_queue_app/src/features/party/domain/models/user_profile.dart';
import 'package:party_queue_app/src/features/party/domain/models/vote_type.dart';
import 'package:party_queue_app/src/features/party/domain/queue_sorting.dart';
import 'package:party_queue_app/src/features/spotify/application/playback_orchestrator.dart';
import 'package:party_queue_app/src/features/spotify/application/spotify_connection_controller.dart';
import 'package:party_queue_app/src/features/spotify/domain/models/playback_command_result.dart';
import 'package:party_queue_app/src/features/spotify/domain/models/spotify_playback_state.dart';
import 'package:party_queue_app/src/features/spotify/domain/spotify_catalog_service.dart';

class PartyRoomController extends ChangeNotifier {
  PartyRoomController({
    required PartyRoomRepository repository,
    required SpotifyCatalogService catalogService,
    required PlaybackOrchestrator playbackOrchestrator,
    SpotifyConnectionController? spotifyConnectionController,
  }) : _repository = repository,
       _catalogService = catalogService,
       _playbackOrchestrator = playbackOrchestrator,
       _spotifyConnectionController = spotifyConnectionController {
    _playbackOrchestrator.addListener(notifyListeners);
    _spotifyConnectionController?.addListener(notifyListeners);
  }

  final PartyRoomRepository _repository;
  final SpotifyCatalogService _catalogService;
  final PlaybackOrchestrator _playbackOrchestrator;
  final SpotifyConnectionController? _spotifyConnectionController;
  StreamSubscription<PartyRoom?>? _roomSub;

  PartyRoom? _room;
  String? _activeUserId;
  String? _error;

  PartyRoom? get room => _room;
  String? get activeUserId => _activeUserId;
  String? get error => _error;
  SpotifyPlaybackState get playbackState =>
      _spotifyConnectionController?.playbackState ??
      const SpotifyPlaybackState();
  bool get isHost =>
      _activeUserId != null && _activeUserId == _room?.hostUserId;
  bool get isHostConnectedToSpotify =>
      _spotifyConnectionController?.connectionState.spotifyConnected ?? false;
  bool get isPlaybackReady => _playbackOrchestrator.canControlPlayback;

  String? get nowPlayingTitle {
    final room = _room;
    if (room == null) {
      return null;
    }
    if (room.nowPlayingTrack != null) {
      return room.nowPlayingTrack!.title;
    }
    final currentId = room.nowPlayingTrackId;
    if (currentId == null) {
      return null;
    }
    for (final item in room.queue) {
      if (item.track.id == currentId) {
        return item.track.title;
      }
    }
    return null;
  }

  Future<void> createRoom({
    required UserProfile host,
    required RoomSettings settings,
  }) async {
    final code = generateRoomCode();
    final hostProfile = host.copyWith(isHost: true);
    final room = PartyRoom(
      code: code,
      hostUserId: host.id,
      settings: settings,
      createdAt: DateTime.now(),
      participants: <String, UserProfile>{host.id: hostProfile},
    );
    _activeUserId = host.id;
    _room = room;
    _error = null;
    await _repository.saveRoom(room);
    _startWatching(code);
  }

  Future<bool> joinRoom({
    required String code,
    required UserProfile user,
  }) async {
    final room = _repository.readRoom(code);
    if (room == null || room.isClosed) {
      _error = 'Room not found or closed.';
      notifyListeners();
      return false;
    }
    if (room.participantCount >= room.settings.maxParticipants &&
        !room.participants.containsKey(user.id)) {
      _error = 'Participant limit reached.';
      notifyListeners();
      return false;
    }
    final updatedParticipants = Map<String, UserProfile>.from(room.participants)
      ..[user.id] = user;
    final updatedRoom = room.copyWith(participants: updatedParticipants);
    _activeUserId = user.id;
    _room = updatedRoom;
    _error = null;
    await _repository.saveRoom(updatedRoom);
    _startWatching(code);
    return true;
  }

  Future<List<SpotifyTrack>> search(String query) async {
    return _catalogService.searchTracks(query);
  }

  Future<void> addTrack(SpotifyTrack track) async {
    final room = _currentRoomSnapshot();
    final userId = _activeUserId;
    if (room == null || userId == null) {
      return;
    }
    if (_isTrackInCooldown(room, track.id)) {
      _error = 'Track is in cooldown.';
      notifyListeners();
      return;
    }
    if (room.queue.any((item) => item.track.id == track.id)) {
      _error = 'Track already exists in queue.';
      notifyListeners();
      return;
    }

    _error = null;
    final updatedRoom = room.copyWith(
      queue: sortedQueue(
        List<QueueItem>.from(room.queue)
          ..add(
            QueueItem(
              track: track,
              addedByUserId: userId,
              addedAt: DateTime.now(),
            ),
          ),
      ),
    );
    _room = updatedRoom;
    await _repository.saveRoom(updatedRoom);
  }

  Future<void> vote({
    required String trackId,
    required VoteType voteType,
  }) async {
    final room = _currentRoomSnapshot();
    final userId = _activeUserId;
    if (room == null || userId == null) {
      return;
    }
    if (_isTrackInCooldown(room, trackId)) {
      _error = 'Voting locked during cooldown.';
      notifyListeners();
      return;
    }

    _error = null;
    final updatedQueue = room.queue.map((item) {
      if (item.track.id != trackId) {
        return item;
      }
      final updatedVotes = Map<String, VoteType>.from(item.votes);
      final current = updatedVotes[userId] ?? VoteType.none;
      if (current == voteType || voteType == VoteType.none) {
        updatedVotes.remove(userId);
      } else {
        updatedVotes[userId] = voteType;
      }
      return item.copyWith(votes: updatedVotes);
    }).toList();

    final updatedRoom = room.copyWith(queue: sortedQueue(updatedQueue));
    _room = updatedRoom;
    await _repository.saveRoom(updatedRoom);
  }

  Future<void> playTopSong() async {
    final room = _currentRoomSnapshot();
    if (room == null || !isHost) {
      return;
    }
    final available = room.queue
        .where((item) => !_isTrackInCooldown(room, item.track.id))
        .toList();
    if (available.isEmpty) {
      _error = 'No songs currently available.';
      notifyListeners();
      return;
    }
    final top = sortedQueue(available).first;
    final intentRoom = room.copyWith(
      desiredNowPlayingTrackId: top.track.id,
      playbackIntent: RoomPlaybackIntent.playTrack(top.track.id),
    );
    _room = intentRoom;
    await _repository.saveRoom(intentRoom);

    _error = null;
    final playbackResult = await _playbackOrchestrator.playTrack(top.track);
    if (!playbackResult.success) {
      await _handlePlaybackFailure(intentRoom, playbackResult);
      return;
    }

    final cooldownUntil = DateTime.now().add(
      Duration(minutes: room.settings.cooldownMinutes),
    );
    final updatedCooldown = Map<String, DateTime>.from(room.cooldownByTrackId)
      ..[top.track.id] = cooldownUntil;
    final updatedQueue = List<QueueItem>.from(room.queue)
      ..removeWhere((item) => item.track.id == top.track.id);
    final updatedRoom = room.copyWith(
      desiredNowPlayingTrackId: top.track.id,
      playbackIntent: const RoomPlaybackIntent.none(),
      nowPlayingTrack: top.track,
      nowPlayingTrackId: top.track.id,
      queue: sortedQueue(updatedQueue),
      cooldownByTrackId: updatedCooldown,
      isPaused: false,
    );
    _room = updatedRoom;
    await _repository.saveRoom(updatedRoom);
  }

  Future<void> skipNowPlaying() async {
    if (!isHost || _room == null) {
      return;
    }
    final room = _currentRoomSnapshot();
    if (room == null) {
      return;
    }
    final intentRoom = room.copyWith(
      playbackIntent: const RoomPlaybackIntent.skip(),
    );
    _room = intentRoom;
    await _repository.saveRoom(intentRoom);
    final result = await _playbackOrchestrator.skip();
    if (!result.success) {
      await _handlePlaybackFailure(intentRoom, result);
      return;
    }
    await playTopSong();
  }

  Future<void> removeSong(String trackId) async {
    final room = _currentRoomSnapshot();
    if (room == null || !isHost) {
      return;
    }
    final updatedQueue = List<QueueItem>.from(room.queue)
      ..removeWhere((item) => item.track.id == trackId);
    final updatedRoom = room.copyWith(queue: sortedQueue(updatedQueue));
    _room = updatedRoom;
    await _repository.saveRoom(updatedRoom);
  }

  Future<void> pauseOrResume() async {
    final room = _currentRoomSnapshot();
    if (room == null || !isHost) {
      return;
    }
    final isResuming = room.isPaused;
    final intentRoom = room.copyWith(
      playbackIntent: isResuming
          ? const RoomPlaybackIntent.resume()
          : const RoomPlaybackIntent.pause(),
    );
    _room = intentRoom;
    await _repository.saveRoom(intentRoom);
    final PlaybackCommandResult result = isResuming
        ? await _playbackOrchestrator.resume()
        : await _playbackOrchestrator.pause();
    if (!result.success) {
      await _handlePlaybackFailure(intentRoom, result);
      return;
    }
    final updatedRoom = room.copyWith(
      isPaused: !room.isPaused,
      playbackIntent: const RoomPlaybackIntent.none(),
    );
    _room = updatedRoom;
    await _repository.saveRoom(updatedRoom);
  }

  Future<void> kickParticipant(String userId) async {
    final room = _currentRoomSnapshot();
    if (room == null || !isHost || userId == room.hostUserId) {
      return;
    }
    final participants = Map<String, UserProfile>.from(room.participants)
      ..remove(userId);
    final updatedRoom = room.copyWith(participants: participants);
    _room = updatedRoom;
    await _repository.saveRoom(updatedRoom);
  }

  Future<void> closeRoom() async {
    final room = _currentRoomSnapshot();
    if (room == null || !isHost) {
      return;
    }
    await _repository.closeRoom(room.code);
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _startWatching(String code) {
    _roomSub?.cancel();
    _roomSub = _repository.watchRoom(code).listen((room) {
      _room = room;
      notifyListeners();
    });
  }

  bool _isTrackInCooldown(PartyRoom room, String trackId) {
    final cooldownUntil = room.cooldownByTrackId[trackId];
    if (cooldownUntil == null) {
      return false;
    }
    return DateTime.now().isBefore(cooldownUntil);
  }

  PartyRoom? _currentRoomSnapshot() {
    final room = _room;
    if (room == null) {
      return null;
    }
    return _repository.readRoom(room.code) ?? room;
  }

  Future<void> _handlePlaybackFailure(
    PartyRoom room,
    PlaybackCommandResult result,
  ) async {
    _error = result.errorMessage;
    final failedRoom = room.copyWith(
      playbackIntent: const RoomPlaybackIntent.none(),
    );
    _room = failedRoom;
    await _repository.saveRoom(failedRoom);
    notifyListeners();
  }

  @override
  void dispose() {
    _roomSub?.cancel();
    _playbackOrchestrator.removeListener(notifyListeners);
    _spotifyConnectionController?.removeListener(notifyListeners);
    super.dispose();
  }
}
