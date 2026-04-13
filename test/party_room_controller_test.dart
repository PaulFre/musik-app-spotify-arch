import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:party_queue_app/src/features/party/application/party_room_controller.dart';
import 'package:party_queue_app/src/features/party/data/party_room_repository.dart';
import 'package:party_queue_app/src/features/party/domain/models/spotify_artist_ref.dart';
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

  test(
    'excluded songs are filtered from search and suggestions and cannot be added',
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

      const excludedTrack = SpotifyTrack(
        id: '3n3Ppam7vgaVa1iaRUc9Lp',
        uri: 'spotify:track:3n3Ppam7vgaVa1iaRUc9Lp',
        title: 'Mr. Brightside',
        artist: 'The Killers',
      );

      await controller.createRoom(
        host: const UserProfile(
          id: 'host-1',
          displayName: 'Host',
          isHost: true,
        ),
        settings: const RoomSettings(
          excludedTracks: <SpotifyTrack>[excludedTrack],
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final searchResults = await controller.search('');
      expect(
        searchResults.any((track) => track.id == excludedTrack.id),
        isFalse,
      );

      final suggestions = await controller.loadSuggestions();
      expect(suggestions.any((track) => track.id == excludedTrack.id), isFalse);

      await controller.addTrack(excludedTrack);
      expect(controller.room!.queue, isEmpty);
      expect(controller.error, 'Dieser Song wurde vom Host ausgeschlossen.');

      controller.dispose();
      harness.dispose();
    },
  );

  test(
    'excluded artists are filtered from search and suggestions and cannot be added',
    () async {
      final harness = await TestSpotifyHarness.ready(
        catalogService: ArtistAwareFakeSpotifyCatalogService(),
      );
      final controller = PartyRoomController(
        repository: InMemoryPartyRoomRepository(),
        catalogService: harness.catalogService,
        playbackOrchestrator: harness.playbackOrchestrator,
        spotifyConnectionController: harness.connectionController,
      );

      const blockedTrack = SpotifyTrack(
        id: 'blocked-artist-track',
        uri: 'spotify:track:blocked-artist-track',
        title: 'Starboy',
        artist: 'The Weeknd',
        artistRefs: <SpotifyArtistRef>[
          SpotifyArtistRef(id: 'artist-weeknd', name: 'The Weeknd'),
        ],
      );

      await controller.createRoom(
        host: const UserProfile(
          id: 'host-1',
          displayName: 'Host',
          isHost: true,
        ),
        settings: const RoomSettings(
          excludedArtists: <SpotifyArtistRef>[
            SpotifyArtistRef(id: 'artist-weeknd', name: 'The Weeknd'),
          ],
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final searchResults = await controller.search('weeknd');
      expect(
        searchResults.any((track) => track.id == blockedTrack.id),
        isFalse,
      );

      final suggestions = await controller.loadSuggestions();
      expect(suggestions.any((track) => track.id == blockedTrack.id), isFalse);

      await controller.addTrack(blockedTrack);
      expect(controller.room!.queue, isEmpty);
      expect(
        controller.error,
        'Dieser Interpret wurde vom Host ausgeschlossen.',
      );

      controller.dispose();
      harness.dispose();
    },
  );

  test(
    'createRoom persists public and private room settings correctly',
    () async {
      final harness = await TestSpotifyHarness.ready(
        catalogService: FakeSpotifyCatalogService(),
      );
      final repository = InMemoryPartyRoomRepository();
      final publicController = PartyRoomController(
        repository: repository,
        catalogService: harness.catalogService,
        playbackOrchestrator: harness.playbackOrchestrator,
        spotifyConnectionController: harness.connectionController,
      );
      final privateController = PartyRoomController(
        repository: repository,
        catalogService: harness.catalogService,
        playbackOrchestrator: harness.playbackOrchestrator,
        spotifyConnectionController: harness.connectionController,
      );

      await publicController.createRoom(
        host: const UserProfile(
          id: 'host-public',
          displayName: 'Host',
          isHost: true,
        ),
        settings: const RoomSettings(isPublic: true, roomPassword: null),
      );
      await privateController.createRoom(
        host: const UserProfile(
          id: 'host-private',
          displayName: 'Host',
          isHost: true,
        ),
        settings: const RoomSettings(
          isPublic: false,
          roomPassword: 'secret123',
        ),
      );

      expect(publicController.room!.settings.isPublic, isTrue);
      expect(publicController.room!.settings.roomPassword, isNull);
      expect(privateController.room!.settings.isPublic, isFalse);
      expect(privateController.room!.settings.roomPassword, 'secret123');

      publicController.dispose();
      privateController.dispose();
      await repository.dispose();
      harness.dispose();
    },
  );

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
    'private room requires correct password while public room does not',
    () async {
      final harness = await TestSpotifyHarness.ready(
        catalogService: FakeSpotifyCatalogService(),
      );
      final repository = InMemoryPartyRoomRepository();
      final privateHost = PartyRoomController(
        repository: repository,
        catalogService: harness.catalogService,
        playbackOrchestrator: harness.playbackOrchestrator,
        spotifyConnectionController: harness.connectionController,
      );
      final privateGuest = PartyRoomController(
        repository: repository,
        catalogService: harness.catalogService,
        playbackOrchestrator: harness.playbackOrchestrator,
        spotifyConnectionController: harness.connectionController,
      );
      final publicHost = PartyRoomController(
        repository: repository,
        catalogService: harness.catalogService,
        playbackOrchestrator: harness.playbackOrchestrator,
        spotifyConnectionController: harness.connectionController,
      );
      final publicGuest = PartyRoomController(
        repository: repository,
        catalogService: harness.catalogService,
        playbackOrchestrator: harness.playbackOrchestrator,
        spotifyConnectionController: harness.connectionController,
      );

      await privateHost.createRoom(
        host: const UserProfile(
          id: 'host-private',
          displayName: 'Host',
          isHost: true,
        ),
        settings: const RoomSettings(
          isPublic: false,
          roomPassword: 'secret123',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final wrongPasswordJoin = await privateGuest.joinRoom(
        code: privateHost.room!.code,
        user: const UserProfile(id: 'guest-private', displayName: 'Gast'),
        password: 'wrong',
      );
      expect(wrongPasswordJoin, isFalse);
      expect(privateGuest.error, 'Passwort fuer privaten Raum ist falsch.');

      final correctPasswordJoin = await privateGuest.joinRoom(
        code: privateHost.room!.code,
        user: const UserProfile(id: 'guest-private', displayName: 'Gast'),
        password: 'secret123',
      );
      expect(correctPasswordJoin, isTrue);

      await publicHost.createRoom(
        host: const UserProfile(
          id: 'host-public',
          displayName: 'Host',
          isHost: true,
        ),
        settings: const RoomSettings(isPublic: true),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final publicJoin = await publicGuest.joinRoom(
        code: publicHost.room!.code,
        user: const UserProfile(id: 'guest-public', displayName: 'Gast'),
      );
      expect(publicJoin, isTrue);

      privateHost.dispose();
      privateGuest.dispose();
      publicHost.dispose();
      publicGuest.dispose();
      await repository.dispose();
      harness.dispose();
    },
  );

  test('host can update room settings and guest cannot', () async {
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
    await guest.joinRoom(
      code: host.room!.code,
      user: const UserProfile(id: 'guest-1', displayName: 'Gast 1'),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final hostUpdated = await host.updateRoomSettings(
      host.room!.settings.copyWith(
        cooldownMinutes: 30,
        maxParticipants: 40,
        maxQueuedTracksPerUser: 5,
      ),
    );
    expect(hostUpdated, isTrue);
    expect(host.room!.settings.cooldownMinutes, 30);
    expect(host.room!.settings.maxParticipants, 40);
    expect(host.room!.settings.maxQueuedTracksPerUser, 5);

    final guestUpdated = await guest.updateRoomSettings(
      guest.room!.settings.copyWith(maxQueuedTracksPerUser: 1),
    );
    expect(guestUpdated, isFalse);
    expect(host.room!.settings.maxQueuedTracksPerUser, 5);

    host.dispose();
    guest.dispose();
    await repository.dispose();
    harness.dispose();
  });

  test(
    'updateRoomSettings does not change public-private mode or room password',
    () async {
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
        host: const UserProfile(
          id: 'host-1',
          displayName: 'Host',
          isHost: true,
        ),
        settings: const RoomSettings(
          isPublic: false,
          roomPassword: 'secret123',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final updated = await controller.updateRoomSettings(
        controller.room!.settings.copyWith(
          cooldownMinutes: 30,
          isPublic: true,
          roomPassword: null,
        ),
      );

      expect(updated, isTrue);
      expect(controller.room!.settings.cooldownMinutes, 30);
      expect(controller.room!.settings.isPublic, isFalse);
      expect(controller.room!.settings.roomPassword, 'secret123');

      controller.dispose();
      await repository.dispose();
      harness.dispose();
    },
  );

  test(
    'update room settings rejects participant limit below current participants',
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
        settings: const RoomSettings(maxParticipants: 5),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await guest.joinRoom(
        code: host.room!.code,
        user: const UserProfile(id: 'guest-1', displayName: 'Gast 1'),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final updated = await host.updateRoomSettings(
        host.room!.settings.copyWith(maxParticipants: 1),
      );
      expect(updated, isFalse);
      expect(
        host.error,
        'Teilnehmerlimit darf nicht unter den aktuellen Teilnehmern liegen.',
      );
      expect(host.room!.settings.maxParticipants, 5);

      host.dispose();
      guest.dispose();
      await repository.dispose();
      harness.dispose();
    },
  );

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

  test(
    'loadSuggestions adapts to room context and excludes queued tracks',
    () async {
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
        host: const UserProfile(
          id: 'host-1',
          displayName: 'Host',
          isHost: true,
        ),
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
    },
  );

  test(
    'loadSuggestions keeps filling across seed results until three suggestions exist',
    () async {
      final catalogService = MultiResultContextCatalogService();
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
        host: const UserProfile(
          id: 'host-1',
          displayName: 'Host',
          isHost: true,
        ),
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

      expect(suggestions, hasLength(3));
      expect(suggestions.map((track) => track.id), <String>[
        'suggestion-1',
        'suggestion-2',
        'fallback-1',
      ]);

      controller.dispose();
      harness.dispose();
    },
  );

  test('loadSuggestions times out safely instead of hanging forever', () async {
    final harness = await TestSpotifyHarness.ready(
      catalogService: HangingSuggestionCatalogService(),
    );
    final controller = PartyRoomController(
      repository: InMemoryPartyRoomRepository(),
      catalogService: harness.catalogService,
      playbackOrchestrator: harness.playbackOrchestrator,
      spotifyConnectionController: harness.connectionController,
      suggestionLoadTimeout: const Duration(milliseconds: 10),
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

    expect(suggestions, isEmpty);

    controller.dispose();
    harness.dispose();
  });

  test(
    'loadSuggestions skips a hanging seed request and still returns later suggestions',
    () async {
      final harness = await TestSpotifyHarness.ready(
        catalogService: HangingSeedThenWorkingCatalogService(),
      );
      final controller = PartyRoomController(
        repository: InMemoryPartyRoomRepository(),
        catalogService: harness.catalogService,
        playbackOrchestrator: harness.playbackOrchestrator,
        spotifyConnectionController: harness.connectionController,
        suggestionLoadTimeout: const Duration(milliseconds: 10),
      );

      await controller.createRoom(
        host: const UserProfile(
          id: 'host-1',
          displayName: 'Host',
          isHost: true,
        ),
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

      expect(suggestions, hasLength(3));
      expect(suggestions.map((track) => track.id), <String>[
        'suggestion-1',
        'suggestion-2',
        'fallback-1',
      ]);

      controller.dispose();
      harness.dispose();
    },
  );

  test(
    'natural song end auto-advances exactly once to the next playable track',
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
      await controller.addTrack(tracks[2]);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      await controller.playTopSong();
      await Future<void>.delayed(const Duration(milliseconds: 100));

      harness.connectionController.applyPlaybackState(
        harness.connectionController.playbackState.copyWith(
          actualNowPlayingTrackId: null,
          actualIsPaused: true,
          playbackErrorCode: null,
          playbackError: null,
          lastSyncedAt: DateTime.now(),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(controller.room!.playbackIntent.isNone, isTrue);
      expect(controller.room!.nowPlayingTrackId, tracks[1].id);
      expect(
        controller.room!.queue.any((item) => item.track.id == tracks[2].id),
        isTrue,
      );

      controller.dispose();
      harness.dispose();
    },
  );

  test(
    'natural song end with progress reset on same track auto-advances',
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
      await Future<void>.delayed(const Duration(milliseconds: 100));

      harness.connectionController.applyPlaybackState(
        harness.connectionController.playbackState.copyWith(
          actualNowPlayingTrackId: tracks[0].id,
          actualProgressMs: 0,
          actualIsPaused: true,
          playbackErrorCode: null,
          playbackError: null,
          lastSyncedAt: DateTime.now(),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(controller.room!.playbackIntent.isNone, isTrue);
      expect(controller.room!.nowPlayingTrackId, tracks[1].id);

      controller.dispose();
      harness.dispose();
    },
  );

  test(
    'natural song end clears now playing when no next track exists',
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
        settings: const RoomSettings(),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final tracks = await controller.search('');
      await controller.addTrack(tracks.first);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      await controller.playTopSong();
      await Future<void>.delayed(const Duration(milliseconds: 100));

      harness.connectionController.applyPlaybackState(
        harness.connectionController.playbackState.copyWith(
          actualNowPlayingTrackId: null,
          actualIsPaused: true,
          playbackErrorCode: null,
          playbackError: null,
          lastSyncedAt: DateTime.now(),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(controller.room!.playbackIntent.isNone, isTrue);
      expect(controller.room!.nowPlayingTrackId, isNull);
      expect(controller.room!.nowPlayingTrack, isNull);
      expect(controller.room!.playbackErrorMessage, isNull);

      controller.dispose();
      harness.dispose();
    },
  );

  test('pause does not trigger auto-advance', () async {
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
      settings: const RoomSettings(),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final tracks = await controller.search('');
    await controller.addTrack(tracks[0]);
    await controller.addTrack(tracks[1]);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    await controller.playTopSong();
    await Future<void>.delayed(const Duration(milliseconds: 100));

    harness.connectionController.applyPlaybackState(
      harness.connectionController.playbackState.copyWith(
        actualNowPlayingTrackId: tracks[0].id,
        actualProgressMs: 0,
        actualIsPaused: true,
        playbackErrorCode: null,
        playbackError: null,
        lastSyncedAt: DateTime.now(),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(controller.room!.playbackIntent.isNone, isTrue);
    expect(controller.room!.nowPlayingTrackId, tracks[0].id);

    controller.dispose();
    harness.dispose();
  });

  test('device unavailable does not trigger false auto-advance', () async {
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
      settings: const RoomSettings(),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final tracks = await controller.search('');
    await controller.addTrack(tracks[0]);
    await controller.addTrack(tracks[1]);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    await controller.playTopSong();
    await Future<void>.delayed(const Duration(milliseconds: 100));

    harness.connectionController.applyPlaybackState(
      harness.connectionController.playbackState.copyWith(
        selectedDeviceId: null,
        actualNowPlayingTrackId: null,
        actualIsPaused: true,
        playbackErrorCode: 'device-unavailable',
        playbackError: 'Das ausgewaehlte Geraet ist nicht mehr verfuegbar.',
        lastSyncedAt: DateTime.now(),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(controller.room!.playbackIntent.isNone, isTrue);
    expect(controller.room!.nowPlayingTrackId, tracks[0].id);

    controller.dispose();
    harness.dispose();
  });

  test(
    'repeated song-end polls do not trigger auto-advance multiple times',
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
        settings: const RoomSettings(),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final tracks = await controller.search('');
      await controller.addTrack(tracks[0]);
      await controller.addTrack(tracks[1]);
      await controller.addTrack(tracks[2]);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      await controller.playTopSong();
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final endedState = harness.connectionController.playbackState.copyWith(
        actualNowPlayingTrackId: null,
        actualIsPaused: true,
        playbackErrorCode: null,
        playbackError: null,
        lastSyncedAt: DateTime.now(),
      );
      harness.connectionController.applyPlaybackState(endedState);
      harness.connectionController.applyPlaybackState(endedState);
      await Future<void>.delayed(const Duration(milliseconds: 140));

      expect(controller.room!.nowPlayingTrackId, tracks[1].id);
      expect(
        controller.room!.queue.any((item) => item.track.id == tracks[2].id),
        isTrue,
      );

      controller.dispose();
      harness.dispose();
    },
  );

  test('skip overlapping with song end does not double-advance', () async {
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
      settings: const RoomSettings(),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final tracks = await controller.search('');
    await controller.addTrack(tracks[0]);
    await controller.addTrack(tracks[1]);
    await controller.addTrack(tracks[2]);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    await controller.playTopSong();
    await Future<void>.delayed(const Duration(milliseconds: 100));

    await controller.skipNowPlaying();
    harness.connectionController.applyPlaybackState(
      harness.connectionController.playbackState.copyWith(
        actualNowPlayingTrackId: null,
        actualIsPaused: true,
        playbackErrorCode: null,
        playbackError: null,
        lastSyncedAt: DateTime.now(),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 160));

    expect(controller.room!.playbackIntent.isNone, isTrue);
    expect(controller.room!.nowPlayingTrackId, tracks[1].id);
    expect(
      controller.room!.queue.any((item) => item.track.id == tracks[2].id),
      isTrue,
    );

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
      actualProgressMs: 0,
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

class ArtistAwareFakeSpotifyCatalogService implements SpotifyCatalogService {
  @override
  Future<List<SpotifyTrack>> loadSuggestions() async {
    return const <SpotifyTrack>[
      SpotifyTrack(
        id: 'blocked-artist-track',
        uri: 'spotify:track:blocked-artist-track',
        title: 'Starboy',
        artist: 'The Weeknd',
        artistRefs: <SpotifyArtistRef>[
          SpotifyArtistRef(id: 'artist-weeknd', name: 'The Weeknd'),
        ],
      ),
      SpotifyTrack(
        id: 'safe-pop-track',
        uri: 'spotify:track:safe-pop-track',
        title: 'Pop Song',
        artist: 'Pop Artist',
        artistRefs: <SpotifyArtistRef>[
          SpotifyArtistRef(id: 'artist-pop', name: 'Pop Artist'),
        ],
      ),
      SpotifyTrack(
        id: 'safe-funk-track',
        uri: 'spotify:track:safe-funk-track',
        title: 'Funk Song',
        artist: 'Funk Artist',
        artistRefs: <SpotifyArtistRef>[
          SpotifyArtistRef(id: 'artist-funk', name: 'Funk Artist'),
        ],
      ),
    ];
  }

  @override
  Future<List<SpotifyTrack>> searchTracks(String query) async {
    return const <SpotifyTrack>[
      SpotifyTrack(
        id: 'blocked-artist-track',
        uri: 'spotify:track:blocked-artist-track',
        title: 'Starboy',
        artist: 'The Weeknd',
        artistRefs: <SpotifyArtistRef>[
          SpotifyArtistRef(id: 'artist-weeknd', name: 'The Weeknd'),
        ],
      ),
      SpotifyTrack(
        id: 'safe-pop-track',
        uri: 'spotify:track:safe-pop-track',
        title: 'Pop Song',
        artist: 'Pop Artist',
        artistRefs: <SpotifyArtistRef>[
          SpotifyArtistRef(id: 'artist-pop', name: 'Pop Artist'),
        ],
      ),
    ];
  }
}

class MultiResultContextCatalogService implements SpotifyCatalogService {
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
        SpotifyTrack(
          id: 'suggestion-2',
          uri: 'spotify:track:suggestion-2',
          title: 'Candy Shop',
          artist: '50 Cent',
        ),
      ];
    }
    if (query == 'Window Shopper') {
      return const <SpotifyTrack>[
        SpotifyTrack(
          id: 'queued-track',
          uri: 'spotify:track:queued-track',
          title: 'Window Shopper',
          artist: '50 Cent',
        ),
      ];
    }
    return const <SpotifyTrack>[];
  }
}

class HangingSuggestionCatalogService implements SpotifyCatalogService {
  @override
  Future<List<SpotifyTrack>> loadSuggestions() {
    return Completer<List<SpotifyTrack>>().future;
  }

  @override
  Future<List<SpotifyTrack>> searchTracks(String query) {
    return Completer<List<SpotifyTrack>>().future;
  }
}

class HangingSeedThenWorkingCatalogService implements SpotifyCatalogService {
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
  Future<List<SpotifyTrack>> searchTracks(String query) {
    if (query == '50 Cent') {
      return Completer<List<SpotifyTrack>>().future;
    }
    if (query == 'Window Shopper') {
      return Future<List<SpotifyTrack>>.value(const <SpotifyTrack>[
        SpotifyTrack(
          id: 'suggestion-1',
          uri: 'spotify:track:suggestion-1',
          title: 'In Da Club',
          artist: '50 Cent',
        ),
        SpotifyTrack(
          id: 'suggestion-2',
          uri: 'spotify:track:suggestion-2',
          title: 'Candy Shop',
          artist: '50 Cent',
        ),
      ]);
    }
    return Future<List<SpotifyTrack>>.value(const <SpotifyTrack>[]);
  }
}

class EmptyCatalogService implements SpotifyCatalogService {
  @override
  Future<List<SpotifyTrack>> loadSuggestions() async {
    return const <SpotifyTrack>[];
  }

  @override
  Future<List<SpotifyTrack>> searchTracks(String query) async {
    return const <SpotifyTrack>[];
  }
}
