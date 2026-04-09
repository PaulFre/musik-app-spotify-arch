import 'package:flutter_test/flutter_test.dart';
import 'package:party_queue_app/src/features/party/application/party_room_controller.dart';
import 'package:party_queue_app/src/features/party/data/party_room_repository.dart';
import 'package:party_queue_app/src/features/party/domain/models/room_playback_intent.dart';
import 'package:party_queue_app/src/features/party/domain/models/room_settings.dart';
import 'package:party_queue_app/src/features/party/domain/models/spotify_track.dart';
import 'package:party_queue_app/src/features/party/domain/models/user_profile.dart';
import 'package:party_queue_app/src/features/party/domain/models/vote_type.dart';
import 'package:party_queue_app/src/features/spotify/application/playback_orchestrator.dart';
import 'package:party_queue_app/src/features/spotify/application/spotify_connection_controller.dart';
import 'package:party_queue_app/src/features/spotify/domain/models/playback_command_result.dart';
import 'package:party_queue_app/src/features/spotify/domain/models/spotify_device.dart';
import 'package:party_queue_app/src/features/spotify/domain/models/spotify_playback_state.dart';
import 'package:party_queue_app/src/features/spotify/domain/spotify_auth_service.dart';
import 'package:party_queue_app/src/features/spotify/domain/spotify_catalog_service.dart';
import 'package:party_queue_app/src/features/spotify/domain/spotify_playback_service.dart';
import 'test_support/test_spotify_harness.dart';

void main() {
  test('prevents duplicate song and toggles vote', () async {
    final harness = await TestSpotifyHarness.ready(
      catalogService: FakeSpotifyCatalogService(),
    );
    final repository = InMemoryPartyRoomRepository();
    final host = PartyRoomController(
      repository: repository,
      catalogService: harness.catalogService,
      playbackOrchestrator: harness.playbackOrchestrator,
      spotifyConnectionController: harness.connectionController,
    );
    final guest = PartyRoomController(
      repository: repository,
      catalogService: harness.catalogService,
      playbackOrchestrator: harness.playbackOrchestrator,
      spotifyConnectionController: harness.connectionController,
    );

    await host.createRoom(
      host: const UserProfile(id: 'host-1', displayName: 'Host', isHost: true),
      settings: const RoomSettings(cooldownMinutes: 15),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final joined = await guest.joinRoom(
      code: host.room!.code,
      user: const UserProfile(id: 'guest-1', displayName: 'Gast 1'),
    );
    expect(joined, isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final results = await host.search('brightside');
    await host.addTrack(results.first);
    await host.addTrack(results.first);
    expect(host.error, isNotNull);

    await guest.vote(trackId: results.first.id, voteType: VoteType.like);
    expect(host.room!.queue.first.score, 1);

    await guest.vote(trackId: results.first.id, voteType: VoteType.like);
    expect(host.room!.queue.first.score, 0);

    host.dispose();
    guest.dispose();
    await repository.dispose();
    harness.dispose();
  });

  test('guest can leave room and host leaving closes room', () async {
    final harness = await TestSpotifyHarness.ready(
      catalogService: FakeSpotifyCatalogService(),
    );
    final repository = InMemoryPartyRoomRepository();
    final host = PartyRoomController(
      repository: repository,
      catalogService: harness.catalogService,
      playbackOrchestrator: harness.playbackOrchestrator,
      spotifyConnectionController: harness.connectionController,
    );
    final guest = PartyRoomController(
      repository: repository,
      catalogService: harness.catalogService,
      playbackOrchestrator: harness.playbackOrchestrator,
      spotifyConnectionController: harness.connectionController,
    );

    await host.createRoom(
      host: const UserProfile(id: 'host-1', displayName: 'Host', isHost: true),
      settings: const RoomSettings(maxParticipants: 5),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final joined = await guest.joinRoom(
      code: host.room!.code,
      user: const UserProfile(id: 'guest-1', displayName: 'Gast 1'),
    );
    expect(joined, isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(guest.hasJoinedRoom, isTrue);

    await guest.leaveRoom();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(guest.activeUserId, isNull);
    expect(guest.hasJoinedRoom, isFalse);
    expect(host.room!.participantCount, 1);

    await host.leaveRoom();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(host.room!.isClosed, isTrue);

    host.dispose();
    guest.dispose();
    await repository.dispose();
    harness.dispose();
  });

  test(
    'vote can switch direction and does not trigger playback intent',
    () async {
      final harness = await TestSpotifyHarness.ready(
        catalogService: FakeSpotifyCatalogService(),
      );
      final repository = InMemoryPartyRoomRepository();
      final host = PartyRoomController(
        repository: repository,
        catalogService: harness.catalogService,
        playbackOrchestrator: harness.playbackOrchestrator,
        spotifyConnectionController: harness.connectionController,
      );
      final guest = PartyRoomController(
        repository: repository,
        catalogService: harness.catalogService,
        playbackOrchestrator: harness.playbackOrchestrator,
        spotifyConnectionController: harness.connectionController,
      );

      await host.createRoom(
        host: const UserProfile(
          id: 'host-1',
          displayName: 'Host',
          isHost: true,
        ),
        settings: const RoomSettings(cooldownMinutes: 15),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final joined = await guest.joinRoom(
        code: host.room!.code,
        user: const UserProfile(id: 'guest-1', displayName: 'Gast 1'),
      );
      expect(joined, isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final results = await host.search('');
      await host.addTrack(results.first);

      await guest.vote(trackId: results.first.id, voteType: VoteType.like);
      expect(host.room!.queue.first.score, 1);
      expect(host.room!.playbackIntent.isNone, isTrue);
      expect(host.room!.desiredNowPlayingTrackId, isNull);

      await guest.vote(trackId: results.first.id, voteType: VoteType.dislike);
      expect(host.room!.queue.first.score, -1);
      expect(host.room!.queue.first.voteOf('guest-1'), VoteType.dislike);
      expect(host.room!.playbackIntent.isNone, isTrue);

      host.dispose();
      guest.dispose();
      await repository.dispose();
      harness.dispose();
    },
  );

  test('vote rejects missing tracks and users who already left', () async {
    final harness = await TestSpotifyHarness.ready(
      catalogService: FakeSpotifyCatalogService(),
    );
    final repository = InMemoryPartyRoomRepository();
    final host = PartyRoomController(
      repository: repository,
      catalogService: harness.catalogService,
      playbackOrchestrator: harness.playbackOrchestrator,
      spotifyConnectionController: harness.connectionController,
    );
    final guest = PartyRoomController(
      repository: repository,
      catalogService: harness.catalogService,
      playbackOrchestrator: harness.playbackOrchestrator,
      spotifyConnectionController: harness.connectionController,
    );

    await host.createRoom(
      host: const UserProfile(id: 'host-1', displayName: 'Host', isHost: true),
      settings: const RoomSettings(maxParticipants: 5),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final joined = await guest.joinRoom(
      code: host.room!.code,
      user: const UserProfile(id: 'guest-1', displayName: 'Gast 1'),
    );
    expect(joined, isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final tracks = await host.search('');
    await host.addTrack(tracks.first);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    await guest.vote(trackId: 'missing-track', voteType: VoteType.like);
    expect(guest.error, 'Track not found in queue.');

    await guest.leaveRoom();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    await guest.vote(trackId: tracks.first.id, voteType: VoteType.like);
    expect(guest.hasJoinedRoom, isFalse);

    host.dispose();
    guest.dispose();
    await repository.dispose();
    harness.dispose();
  });

  test(
    'host play action is consumed and confirmed back into the room',
    () async {
      final harness = await TestSpotifyHarness.ready(
        catalogService: FakeSpotifyCatalogService(),
      );
      final controller = PartyRoomController(
        repository: InMemoryPartyRoomRepository(),
        catalogService: harness.catalogService,
        playbackOrchestrator: harness.playbackOrchestrator,
        spotifyConnectionController: harness.connectionController,
      );

      await controller.createRoom(
        host: const UserProfile(
          id: 'host-1',
          displayName: 'Host',
          isHost: true,
        ),
        settings: const RoomSettings(cooldownMinutes: 15),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final tracks = await controller.search('');
      await controller.addTrack(tracks.first);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      await controller.playTopSong();
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(controller.room!.playbackIntent.isNone, isTrue);
      expect(controller.room!.desiredNowPlayingTrackId, isNull);
      expect(controller.room!.nowPlayingTrackId, tracks.first.id);
      expect(controller.room!.nowPlayingTrack!.title, tracks.first.title);
      expect(controller.nowPlayingTitle, tracks.first.title);
      expect(
        controller.room!.queue.any((item) => item.track.id == tracks.first.id),
        isFalse,
      );
      expect(controller.room!.playbackErrorMessage, isNull);

      controller.dispose();
      harness.dispose();
    },
  );

  test(
    'host pause, resume and skip are confirmed through the same loop',
    () async {
      final harness = await TestSpotifyHarness.ready(
        catalogService: FakeSpotifyCatalogService(),
      );
      final controller = PartyRoomController(
        repository: InMemoryPartyRoomRepository(),
        catalogService: harness.catalogService,
        playbackOrchestrator: harness.playbackOrchestrator,
        spotifyConnectionController: harness.connectionController,
      );

      await controller.createRoom(
        host: const UserProfile(
          id: 'host-1',
          displayName: 'Host',
          isHost: true,
        ),
        settings: const RoomSettings(cooldownMinutes: 15),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final tracks = await controller.search('');
      await controller.addTrack(tracks[0]);
      await controller.addTrack(tracks[1]);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      await controller.playTopSong();
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(controller.room!.nowPlayingTrackId, tracks[0].id);
      expect(
        controller.room!.queue.any((item) => item.track.id == tracks[1].id),
        isTrue,
      );

      await controller.pauseOrResume();
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(controller.room!.playbackIntent.isNone, isTrue);
      expect(controller.room!.isPaused, isTrue);
      expect(controller.room!.nowPlayingTrackId, tracks[0].id);

      await controller.pauseOrResume();
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(controller.room!.playbackIntent.isNone, isTrue);
      expect(controller.room!.isPaused, isFalse);
      expect(controller.room!.nowPlayingTrackId, tracks[0].id);

      await controller.skipNowPlaying();
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(controller.room!.playbackIntent.isNone, isTrue);
      expect(controller.room!.nowPlayingTrackId, tracks[1].id);
      expect(controller.room!.nowPlayingTrack!.title, tracks[1].title);
      expect(
        controller.room!.queue.any((item) => item.track.id == tracks[1].id),
        isFalse,
      );
      expect(controller.room!.playbackErrorMessage, isNull);

      controller.dispose();
      harness.dispose();
    },
  );

  test(
    'failed play intent is cleared and writes playback error into room',
    () async {
      final connectionController = SpotifyConnectionController(
        authService: FakeSpotifyAuthService(),
        playbackService: FakeSpotifyPlaybackService(),
      );
      final orchestrator = PlaybackOrchestrator(
        connectionController: connectionController,
      );
      final controller = PartyRoomController(
        repository: InMemoryPartyRoomRepository(),
        catalogService: FakeSpotifyCatalogService(),
        playbackOrchestrator: orchestrator,
        spotifyConnectionController: connectionController,
      );

      await controller.createRoom(
        host: const UserProfile(
          id: 'host-1',
          displayName: 'Host',
          isHost: true,
        ),
        settings: const RoomSettings(cooldownMinutes: 15),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final tracks = await controller.search('');
      await controller.addTrack(tracks.first);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      await controller.playTopSong();
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(controller.room!.playbackIntent.isNone, isTrue);
      expect(controller.room!.nowPlayingTrackId, isNull);
      expect(
        controller.room!.playbackErrorMessage,
        'Spotify ist nicht verbunden.',
      );
      expect(
        controller.room!.queue.any((item) => item.track.id == tracks.first.id),
        isTrue,
      );

      controller.dispose();
      orchestrator.dispose();
      connectionController.dispose();
    },
  );

  test('prevents queue spam by limiting queued songs per user', () async {
    final harness = await TestSpotifyHarness.ready(
      catalogService: FakeSpotifyCatalogService(),
    );
    final controller = PartyRoomController(
      repository: InMemoryPartyRoomRepository(),
      catalogService: harness.catalogService,
      playbackOrchestrator: harness.playbackOrchestrator,
      spotifyConnectionController: harness.connectionController,
    );

    await controller.createRoom(
      host: const UserProfile(id: 'host-1', displayName: 'Host', isHost: true),
      settings: const RoomSettings(maxQueuedTracksPerUser: 2),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final tracks = await controller.search('');
    await controller.addTrack(tracks[0]);
    await controller.addTrack(tracks[1]);
    await controller.addTrack(tracks[2]);

    expect(controller.room!.queue.length, 2);
    expect(controller.error, 'You already reached your queue limit.');

    controller.dispose();
    harness.dispose();
  });

  test('prevents self voting but still allows other users to vote', () async {
    final harness = await TestSpotifyHarness.ready(
      catalogService: FakeSpotifyCatalogService(),
    );
    final repository = InMemoryPartyRoomRepository();
    final host = PartyRoomController(
      repository: repository,
      catalogService: harness.catalogService,
      playbackOrchestrator: harness.playbackOrchestrator,
      spotifyConnectionController: harness.connectionController,
    );
    final guest = PartyRoomController(
      repository: repository,
      catalogService: harness.catalogService,
      playbackOrchestrator: harness.playbackOrchestrator,
      spotifyConnectionController: harness.connectionController,
    );

    await host.createRoom(
      host: const UserProfile(id: 'host-1', displayName: 'Host', isHost: true),
      settings: const RoomSettings(),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final joined = await guest.joinRoom(
      code: host.room!.code,
      user: const UserProfile(id: 'guest-1', displayName: 'Gast 1'),
    );
    expect(joined, isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final tracks = await host.search('');
    await host.addTrack(tracks.first);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    await host.vote(trackId: tracks.first.id, voteType: VoteType.like);
    expect(host.error, 'You cannot vote for your own track.');
    expect(host.room!.queue.first.score, 0);

    await guest.vote(trackId: tracks.first.id, voteType: VoteType.like);
    expect(host.room!.queue.first.score, 1);

    host.dispose();
    guest.dispose();
    await repository.dispose();
    harness.dispose();
  });

  test('newer play intent supersedes an older in-flight play intent', () async {
    final playbackService = SlowFakeSpotifyPlaybackService();
    final connectionController = SpotifyConnectionController(
      authService: FakeSpotifyAuthService(),
      playbackService: playbackService,
    );
    final orchestrator = PlaybackOrchestrator(
      connectionController: connectionController,
    );
    await connectionController.connectHost();
    await connectionController.selectDevice('device-speaker');

    final repository = InMemoryPartyRoomRepository();
    final host = PartyRoomController(
      repository: repository,
      catalogService: FakeSpotifyCatalogService(),
      playbackOrchestrator: orchestrator,
      spotifyConnectionController: connectionController,
    );
    final guest = PartyRoomController(
      repository: repository,
      catalogService: FakeSpotifyCatalogService(),
      playbackOrchestrator: orchestrator,
      spotifyConnectionController: connectionController,
    );

    await host.createRoom(
      host: const UserProfile(id: 'host-1', displayName: 'Host', isHost: true),
      settings: const RoomSettings(cooldownMinutes: 15),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final joined = await guest.joinRoom(
      code: host.room!.code,
      user: const UserProfile(id: 'guest-1', displayName: 'Gast 1'),
    );
    expect(joined, isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final tracks = await host.search('');
    await host.addTrack(tracks[0]);
    await guest.addTrack(tracks[1]);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    await host.playTopSong();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(host.room!.playbackIntent.trackId, tracks[0].id);
    final firstIntentVersion = host.room!.playbackIntentVersion;

    await guest.vote(trackId: tracks[1].id, voteType: VoteType.like);
    await host.vote(trackId: tracks[1].id, voteType: VoteType.like);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    await host.playTopSong();
    final secondIntentVersion = host.room!.playbackIntentVersion;
    expect(secondIntentVersion, greaterThan(firstIntentVersion));
    expect(host.room!.playbackIntent.trackId, tracks[1].id);

    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(host.room!.playbackIntent.isNone, isTrue);
    expect(host.room!.nowPlayingTrackId, tracks[1].id);
    expect(host.room!.nowPlayingTrack!.title, tracks[1].title);
    expect(
      host.room!.queue.any((item) => item.track.id == tracks[1].id),
      isFalse,
    );
    expect(
      host.room!.queue.any((item) => item.track.id == tracks[0].id),
      isTrue,
    );

    host.dispose();
    guest.dispose();
    await repository.dispose();
    orchestrator.dispose();
    connectionController.dispose();
  });

  test(
    'controller host actions stage intents before processor confirmation',
    () async {
      final playbackService = SlowFakeSpotifyPlaybackService(
        playDelay: const Duration(milliseconds: 90),
        pauseDelay: const Duration(milliseconds: 90),
        resumeDelay: const Duration(milliseconds: 90),
        skipDelay: const Duration(milliseconds: 90),
      );
      final connectionController = SpotifyConnectionController(
        authService: FakeSpotifyAuthService(),
        playbackService: playbackService,
      );
      final orchestrator = PlaybackOrchestrator(
        connectionController: connectionController,
      );
      await connectionController.connectHost();
      await connectionController.selectDevice('device-speaker');

      final repository = InMemoryPartyRoomRepository();
      final controller = PartyRoomController(
        repository: repository,
        catalogService: FakeSpotifyCatalogService(),
        playbackOrchestrator: orchestrator,
        spotifyConnectionController: connectionController,
      );

      await controller.createRoom(
        host: const UserProfile(
          id: 'host-1',
          displayName: 'Host',
          isHost: true,
        ),
        settings: const RoomSettings(cooldownMinutes: 15),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final tracks = await controller.search('');
      await controller.addTrack(tracks[0]);
      await controller.addTrack(tracks[1]);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      await controller.playTopSong();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(
        controller.room!.playbackIntent.type,
        RoomPlaybackIntentType.playTrack,
      );
      expect(controller.room!.playbackIntent.trackId, tracks[0].id);
      expect(controller.room!.nowPlayingTrackId, isNull);
      expect(
        controller.room!.queue.any((item) => item.track.id == tracks[0].id),
        isTrue,
      );

      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(controller.room!.playbackIntent.isNone, isTrue);
      expect(controller.room!.nowPlayingTrackId, tracks[0].id);

      await controller.pauseOrResume();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(
        controller.room!.playbackIntent.type,
        RoomPlaybackIntentType.pause,
      );
      expect(controller.room!.isPaused, isFalse);

      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(controller.room!.playbackIntent.isNone, isTrue);
      expect(controller.room!.isPaused, isTrue);

      await controller.skipNowPlaying();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(controller.room!.playbackIntent.type, RoomPlaybackIntentType.skip);
      expect(controller.room!.nowPlayingTrackId, tracks[0].id);

      await Future<void>.delayed(const Duration(milliseconds: 220));
      expect(controller.room!.playbackIntent.isNone, isTrue);
      expect(controller.room!.nowPlayingTrackId, tracks[1].id);

      controller.dispose();
      await repository.dispose();
      orchestrator.dispose();
      connectionController.dispose();
    },
  );

  test('loadSuggestions adapts to room context and excludes queued tracks', () async {
    final catalogService = ContextAwareCatalogService();
    final harness = await TestSpotifyHarness.ready(
      catalogService: catalogService,
    );
    final controller = PartyRoomController(
      repository: InMemoryPartyRoomRepository(),
      catalogService: harness.catalogService,
      playbackOrchestrator: harness.playbackOrchestrator,
      spotifyConnectionController: harness.connectionController,
    );

    await controller.createRoom(
      host: const UserProfile(id: 'host-1', displayName: 'Host', isHost: true),
      settings: const RoomSettings(),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));

    await controller.addTrack(
      const SpotifyTrack(
        id: 'queued-track',
        uri: 'spotify:track:queued-track',
        title: 'Window Shopper',
        artist: '50 Cent',
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final suggestions = await controller.loadSuggestions();

    expect(catalogService.searchQueries, contains('50 Cent'));
    expect(suggestions, hasLength(3));
    expect(suggestions.any((track) => track.id == 'queued-track'), isFalse);

    controller.dispose();
    harness.dispose();
  });
}

class SlowFakeSpotifyPlaybackService implements SpotifyPlaybackService {
  SlowFakeSpotifyPlaybackService({
    this.playDelay = const Duration(milliseconds: 90),
    this.pauseDelay = Duration.zero,
    this.resumeDelay = Duration.zero,
    this.skipDelay = Duration.zero,
  });

  static const List<SpotifyDevice> _devices = <SpotifyDevice>[
    SpotifyDevice(
      id: 'device-speaker',
      name: 'Wohnzimmer Speaker',
      type: 'speaker',
    ),
  ];

  SpotifyPlaybackState _state = const SpotifyPlaybackState(
    availableDevices: _devices,
  );
  final Duration playDelay;
  final Duration pauseDelay;
  final Duration resumeDelay;
  final Duration skipDelay;

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
  Future<PlaybackCommandResult> pause() async {
    await Future<void>.delayed(pauseDelay);
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
  Future<PlaybackCommandResult> playTrack(SpotifyTrack track) async {
    await Future<void>.delayed(playDelay);
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
    await Future<void>.delayed(resumeDelay);
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
  Future<PlaybackCommandResult> skip() async {
    await Future<void>.delayed(skipDelay);
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

class ContextAwareCatalogService implements SpotifyCatalogService {
  final List<String> searchQueries = <String>[];

  @override
  Future<List<SpotifyTrack>> loadSuggestions() async {
    return const <SpotifyTrack>[
      SpotifyTrack(
        id: 'fallback-1',
        uri: 'spotify:track:fallback-1',
        title: 'Fallback 1',
        artist: 'Fallback Artist',
      ),
      SpotifyTrack(
        id: 'fallback-2',
        uri: 'spotify:track:fallback-2',
        title: 'Fallback 2',
        artist: 'Fallback Artist',
      ),
      SpotifyTrack(
        id: 'fallback-3',
        uri: 'spotify:track:fallback-3',
        title: 'Fallback 3',
        artist: 'Fallback Artist',
      ),
    ];
  }

  @override
  Future<List<SpotifyTrack>> searchTracks(String query) async {
    searchQueries.add(query);
    if (query == '50 Cent') {
      return const <SpotifyTrack>[
        SpotifyTrack(
          id: 'queued-track',
          uri: 'spotify:track:queued-track',
          title: 'Window Shopper',
          artist: '50 Cent',
        ),
        SpotifyTrack(
          id: 'suggestion-1',
          uri: 'spotify:track:suggestion-1',
          title: 'In Da Club',
          artist: '50 Cent',
        ),
      ];
    }
    if (query == 'Window Shopper') {
      return const <SpotifyTrack>[
        SpotifyTrack(
          id: 'suggestion-2',
          uri: 'spotify:track:suggestion-2',
          title: 'Candy Shop',
          artist: '50 Cent',
        ),
      ];
    }
    return const <SpotifyTrack>[];
  }
}
