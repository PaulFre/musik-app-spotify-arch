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
import 'package:party_queue_app/src/features/spotify/application/room_playback_intent_processor.dart';
import 'package:party_queue_app/src/features/spotify/application/spotify_connection_controller.dart';
import 'package:party_queue_app/src/features/spotify/domain/models/spotify_playback_state.dart';
import 'package:party_queue_app/src/features/spotify/domain/spotify_catalog_service.dart';

class PartyRoomController extends ChangeNotifier {
  PartyRoomController({
    required PartyRoomRepository repository,
    required SpotifyCatalogService catalogService,
    required PlaybackOrchestrator playbackOrchestrator,
    SpotifyConnectionController? spotifyConnectionController,
    RoomPlaybackIntentProcessor? roomPlaybackIntentProcessor,
  }) : _repository = repository,
       _catalogService = catalogService,
       _playbackOrchestrator = playbackOrchestrator,
       _spotifyConnectionController = spotifyConnectionController,
       _roomPlaybackIntentProcessor =
           roomPlaybackIntentProcessor ??
           RoomPlaybackIntentProcessor(
             repository: repository,
             playbackOrchestrator: playbackOrchestrator,
           ) {
    _playbackOrchestrator.addListener(notifyListeners);
    _previousPlaybackState = _spotifyConnectionController?.playbackState;
    _spotifyConnectionController?.addListener(_handleSpotifyStateChanged);
  }

  final PartyRoomRepository _repository;
  final SpotifyCatalogService _catalogService;
  final PlaybackOrchestrator _playbackOrchestrator;
  final SpotifyConnectionController? _spotifyConnectionController;
  final RoomPlaybackIntentProcessor _roomPlaybackIntentProcessor;
  StreamSubscription<PartyRoom?>? _roomSub;

  PartyRoom? _room;
  String? _activeUserId;
  String? _error;
  SpotifyPlaybackState? _previousPlaybackState;
  String? _autoAdvanceHandledTrackId;

  PartyRoom? get room => _room;
  String? get activeUserId => _activeUserId;
  String? get error => _error;
  bool get hasJoinedRoom =>
      _room != null &&
      _activeUserId != null &&
      _room!.participants.containsKey(_activeUserId);
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
    _roomPlaybackIntentProcessor.start(code);
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
    if (user.id == updatedRoom.hostUserId) {
      _roomPlaybackIntentProcessor.start(code);
    }
    return true;
  }

  Future<List<SpotifyTrack>> search(String query) async {
    return _catalogService.searchTracks(query);
  }

  Future<List<SpotifyTrack>> loadSuggestions() async {
    final room = _currentRoomSnapshot();
    if (room == null) {
      return _catalogService.loadSuggestions();
    }

    final excludedTrackIds = <String>{
      if (room.nowPlayingTrackId != null) room.nowPlayingTrackId!,
      ...room.queue.map((item) => item.track.id),
    };
    final seedQueries = <String>[];

    void addSeed(String? value) {
      final normalized = value?.trim();
      if (normalized == null || normalized.isEmpty) {
        return;
      }
      if (!seedQueries.contains(normalized)) {
        seedQueries.add(normalized);
      }
    }

    addSeed(room.nowPlayingTrack?.artist);
    addSeed(room.nowPlayingTrack?.title);
    for (final item in room.queue.take(5)) {
      addSeed(item.track.artist);
      addSeed(item.track.title);
    }

    final suggestions = <SpotifyTrack>[];
    final seenTrackIds = <String>{};
    for (final seed in seedQueries) {
      final results = await _catalogService.searchTracks(seed);
      for (final track in results) {
        if (excludedTrackIds.contains(track.id)) {
          continue;
        }
        if (!seenTrackIds.add(track.id)) {
          continue;
        }
        suggestions.add(track);
        break;
      }
      if (suggestions.length == 3) {
        return suggestions;
      }
    }

    if (suggestions.length < 3) {
      final fallback = await _catalogService.loadSuggestions();
      for (final track in fallback) {
        if (excludedTrackIds.contains(track.id)) {
          continue;
        }
        if (!seenTrackIds.add(track.id)) {
          continue;
        }
        suggestions.add(track);
        if (suggestions.length == 3) {
          break;
        }
      }
    }

    return suggestions.take(3).toList();
  }

  Future<void> addTrack(SpotifyTrack track) async {
    final room = _currentRoomSnapshot();
    final userId = _activeUserId;
    if (room == null || userId == null) {
      return;
    }
    if (room.isClosed) {
      _error = 'Room not found or closed.';
      notifyListeners();
      return;
    }
    if (!room.participants.containsKey(userId)) {
      _error = 'You are no longer part of this room.';
      notifyListeners();
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
    final queuedByUser = room.queue
        .where((item) => item.addedByUserId == userId)
        .length;
    if (queuedByUser >= room.settings.maxQueuedTracksPerUser) {
      _error = 'You already reached your queue limit.';
      notifyListeners();
      return;
    }

    _error = null;
    final updatedRoom = room.copyWith(
      queue: sortedQueue(
        List<QueueItem>.from(room.queue)..add(
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
    if (room.isClosed) {
      _error = 'Room not found or closed.';
      notifyListeners();
      return;
    }
    if (!room.participants.containsKey(userId)) {
      _error = 'You are no longer part of this room.';
      notifyListeners();
      return;
    }
    if (_isTrackInCooldown(room, trackId)) {
      _error = 'Voting locked during cooldown.';
      notifyListeners();
      return;
    }
    final trackExists = room.queue.any((item) => item.track.id == trackId);
    if (!trackExists) {
      _error = 'Track not found in queue.';
      notifyListeners();
      return;
    }
    final target = room.queue.firstWhere((item) => item.track.id == trackId);
    if (target.addedByUserId == userId) {
      _error = 'You cannot vote for your own track.';
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
    _error = null;
    final intentRoom = room.copyWith(
      desiredNowPlayingTrackId: top.track.id,
      playbackIntent: RoomPlaybackIntent.playTrack(top.track.id),
      playbackIntentVersion: _nextPlaybackIntentVersion(room),
      playbackErrorMessage: null,
    );
    _room = intentRoom;
    await _repository.saveRoom(intentRoom);
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
      playbackIntentVersion: _nextPlaybackIntentVersion(room),
      playbackErrorMessage: null,
    );
    _error = null;
    _room = intentRoom;
    await _repository.saveRoom(intentRoom);
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
      playbackIntentVersion: _nextPlaybackIntentVersion(room),
      playbackErrorMessage: null,
    );
    _error = null;
    _room = intentRoom;
    await _repository.saveRoom(intentRoom);
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

  Future<bool> updateRoomSettings(RoomSettings settings) async {
    final room = _currentRoomSnapshot();
    if (room == null || !isHost) {
      return false;
    }

    if (settings.maxParticipants < room.participantCount) {
      _error =
          'Teilnehmerlimit darf nicht unter den aktuellen Teilnehmern liegen.';
      notifyListeners();
      return false;
    }
    if (settings.maxQueuedTracksPerUser < 1) {
      _error = 'Queue-Limit pro Nutzer muss mindestens 1 sein.';
      notifyListeners();
      return false;
    }
    if (settings.cooldownMinutes < 0) {
      _error = 'Cooldown darf nicht negativ sein.';
      notifyListeners();
      return false;
    }

    _error = null;
    final updatedRoom = room.copyWith(
      settings: settings,
      playbackErrorMessage: room.playbackErrorMessage,
    );
    _room = updatedRoom;
    await _repository.saveRoom(updatedRoom);
    return true;
  }

  Future<void> closeRoom() async {
    final room = _currentRoomSnapshot();
    if (room == null || !isHost) {
      return;
    }
    await _repository.closeRoom(room.code);
  }

  Future<void> leaveRoom() async {
    final room = _currentRoomSnapshot();
    final userId = _activeUserId;
    if (room == null || userId == null) {
      return;
    }

    if (isHost) {
      _roomPlaybackIntentProcessor.stop();
      await closeRoom();
      _roomSub?.cancel();
      _roomSub = null;
      _activeUserId = null;
      notifyListeners();
      return;
    }

    final participants = Map<String, UserProfile>.from(room.participants)
      ..remove(userId);
    final updatedRoom = room.copyWith(participants: participants);
    await _repository.saveRoom(updatedRoom);
    _roomSub?.cancel();
    _roomSub = null;
    _room = updatedRoom;
    _activeUserId = null;
    _error = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _startWatching(String code) {
    _roomSub?.cancel();
    _roomSub = _repository.watchRoom(code).listen((room) {
      _room = room;
      if (room == null ||
          room.nowPlayingTrackId != _autoAdvanceHandledTrackId) {
        _autoAdvanceHandledTrackId = null;
      }
      notifyListeners();
    });
  }

  void _handleSpotifyStateChanged() {
    final nextPlaybackState = _spotifyConnectionController?.playbackState;
    final previousPlaybackState = _previousPlaybackState;
    _previousPlaybackState = nextPlaybackState;
    if (nextPlaybackState != null && previousPlaybackState != null) {
      unawaited(
        _maybeAutoAdvanceAfterNaturalTrackEnd(
          previousPlaybackState: previousPlaybackState,
          nextPlaybackState: nextPlaybackState,
        ),
      );
    }
    notifyListeners();
  }

  Future<void> _maybeAutoAdvanceAfterNaturalTrackEnd({
    required SpotifyPlaybackState previousPlaybackState,
    required SpotifyPlaybackState nextPlaybackState,
  }) async {
    final room = _currentRoomSnapshot();
    if (room == null || !isHost) {
      return;
    }

    final currentTrackId = room.nowPlayingTrackId;
    if (currentTrackId == null) {
      return;
    }
    if (!room.playbackIntent.isNone) {
      return;
    }
    if (_autoAdvanceHandledTrackId == currentTrackId) {
      return;
    }

    final naturalEndDetected =
        previousPlaybackState.actualNowPlayingTrackId == currentTrackId &&
        !previousPlaybackState.actualIsPaused &&
        previousPlaybackState.playbackErrorCode == null &&
        nextPlaybackState.actualNowPlayingTrackId == null &&
        nextPlaybackState.actualIsPaused &&
        nextPlaybackState.playbackErrorCode == null &&
        nextPlaybackState.hasSelectedDevice;
    if (!naturalEndDetected) {
      return;
    }

    _autoAdvanceHandledTrackId = currentTrackId;
    final nextTrack = _nextPlayableQueueItemExcluding(room, currentTrackId);
    if (nextTrack == null) {
      final clearedRoom = room.copyWith(
        playbackIntent: const RoomPlaybackIntent.none(),
        desiredNowPlayingTrackId: null,
        nowPlayingTrack: null,
        nowPlayingTrackId: null,
        isPaused: false,
        playbackErrorMessage: null,
      );
      _room = clearedRoom;
      await _repository.saveRoom(clearedRoom);
      return;
    }

    final intentRoom = room.copyWith(
      playbackIntent: RoomPlaybackIntent.playTrack(nextTrack.track.id),
      playbackIntentVersion: _nextPlaybackIntentVersion(room),
      desiredNowPlayingTrackId: nextTrack.track.id,
      playbackErrorMessage: null,
    );
    _room = intentRoom;
    await _repository.saveRoom(intentRoom);
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

  int _nextPlaybackIntentVersion(PartyRoom room) {
    return room.playbackIntentVersion + 1;
  }

  QueueItem? _nextPlayableQueueItemExcluding(
    PartyRoom room,
    String excludedTrackId,
  ) {
    for (final item in room.queue) {
      if (item.track.id == excludedTrackId) {
        continue;
      }
      if (!_isTrackInCooldown(room, item.track.id)) {
        return item;
      }
    }
    return null;
  }

  @override
  void dispose() {
    _roomPlaybackIntentProcessor.dispose();
    _roomSub?.cancel();
    _playbackOrchestrator.removeListener(notifyListeners);
    _spotifyConnectionController?.removeListener(_handleSpotifyStateChanged);
    super.dispose();
  }
}
