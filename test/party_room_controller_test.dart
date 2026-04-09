import 'package:flutter_test/flutter_test.dart';
import 'package:party_queue_app/src/features/party/application/party_room_controller.dart';
import 'package:party_queue_app/src/features/party/data/party_room_repository.dart';
import 'package:party_queue_app/src/features/party/domain/models/room_playback_intent.dart';
import 'package:party_queue_app/src/features/party/domain/models/room_settings.dart';
import 'package:party_queue_app/src/features/party/domain/models/user_profile.dart';
import 'package:party_queue_app/src/features/party/domain/models/vote_type.dart';
import 'package:party_queue_app/src/features/spotify/domain/spotify_catalog_service.dart';
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

      await guest.vote(
        trackId: results.first.id,
        voteType: VoteType.dislike,
      );
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
    'host play action sets only playback intent and desired track',
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
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(
        controller.room!.playbackIntent.type,
        RoomPlaybackIntentType.playTrack,
      );
      expect(controller.room!.playbackIntent.trackId, tracks.first.id);
      expect(controller.room!.desiredNowPlayingTrackId, tracks.first.id);
      expect(controller.room!.nowPlayingTrackId, isNull);
      expect(controller.room!.nowPlayingTrack, isNull);
      expect(controller.room!.queue.first.track.id, tracks.first.id);

      controller.dispose();
      harness.dispose();
    },
  );

  test('host pause and skip actions stay as pending intents only', () async {
    final harness = await TestSpotifyHarness.ready(
      catalogService: FakeSpotifyCatalogService(),
    );
    final repository = InMemoryPartyRoomRepository();
    final controller = PartyRoomController(
      repository: repository,
      catalogService: harness.catalogService,
      playbackOrchestrator: harness.playbackOrchestrator,
      spotifyConnectionController: harness.connectionController,
    );

    await controller.createRoom(
      host: const UserProfile(id: 'host-1', displayName: 'Host', isHost: true),
      settings: const RoomSettings(cooldownMinutes: 15),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final roomWithPlayback = controller.room!.copyWith(
      nowPlayingTrack: harness.catalogService is FakeSpotifyCatalogService
          ? (await controller.search('')).first
          : null,
      nowPlayingTrackId: (await controller.search('')).first.id,
      isPaused: false,
    );
    await repository.saveRoom(roomWithPlayback);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    await controller.pauseOrResume();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(controller.room!.playbackIntent.type, RoomPlaybackIntentType.pause);
    expect(controller.room!.isPaused, isFalse);

    await controller.skipNowPlaying();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(controller.room!.playbackIntent.type, RoomPlaybackIntentType.skip);
    expect(
      controller.room!.nowPlayingTrackId,
      roomWithPlayback.nowPlayingTrackId,
    );

    controller.dispose();
    await repository.dispose();
    harness.dispose();
  });

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
}
