import 'package:flutter_test/flutter_test.dart';
import 'package:party_queue_app/src/features/party/application/party_room_controller.dart';
import 'package:party_queue_app/src/features/party/data/party_room_repository.dart';
import 'package:party_queue_app/src/features/party/domain/models/room_playback_intent.dart';
import 'package:party_queue_app/src/features/party/domain/models/room_settings.dart';
import 'package:party_queue_app/src/features/party/domain/models/user_profile.dart';
import 'package:party_queue_app/src/features/party/domain/models/vote_type.dart';
import 'test_support/test_spotify_harness.dart';

void main() {
  late InMemoryPartyRoomRepository repository;
  late TestSpotifyHarness harness;
  final createdControllers = <PartyRoomController>[];

  PartyRoomController createController() {
    final controller = PartyRoomController(
      repository: repository,
      catalogService: harness.catalogService,
      playbackOrchestrator: harness.playbackOrchestrator,
      spotifyConnectionController: harness.connectionController,
    );
    createdControllers.add(controller);
    return controller;
  }

  setUp(() async {
    repository = InMemoryPartyRoomRepository();
    harness = await TestSpotifyHarness.ready(
      catalogService: LargeCatalogService(trackCount: 50),
    );
    createdControllers.clear();
  });

  tearDown(() async {
    for (final controller in createdControllers) {
      controller.dispose();
    }
    await _settle();
    expect(repository.activeListenerCount, 0);
    await repository.dispose();
    harness.dispose();
  });

  test(
    'stress test: host and 30 guests survive repeated activity waves',
    () async {
      final host = createController();

      await host.createRoom(
        host: const UserProfile(
          id: 'host-1',
          displayName: 'Host',
          isHost: true,
        ),
        settings: const RoomSettings(cooldownMinutes: 5, maxParticipants: 40),
      );
      await _settle();

      final guests = List<PartyRoomController>.generate(
        30,
        (_) => createController(),
      );

      for (var index = 0; index < guests.length; index++) {
        final joined = await guests[index].joinRoom(
          code: host.room!.code,
          user: UserProfile(id: 'guest-$index', displayName: 'Gast $index'),
        );
        expect(joined, isTrue);
        if (index % 5 == 4) {
          await _settle();
        }
      }
      await _settle();

      expect(host.room!.participantCount, 31);
      expect(
        guests.every((guest) => guest.room!.participantCount == 31),
        isTrue,
      );

      final tracks = await host.search('');
      final actors = <PartyRoomController>[host, ...guests];

      for (var wave = 0; wave < 4; wave++) {
        final startIndex = wave * 5;

        for (var offset = 0; offset < 5; offset++) {
          final actor = actors[startIndex + offset];
          await actor.addTrack(tracks[startIndex + offset]);
        }
        await _settle();

        final queueIds = host.room!.queue.map((item) => item.track.id).toList();
        expect(queueIds.toSet().length, queueIds.length);

        for (var offset = 0; offset < actors.length; offset++) {
          final actor = actors[offset];
          final targetTrack = tracks[startIndex + (offset % 5)];
          final voteType = offset % 3 == 0 ? VoteType.dislike : VoteType.like;
          await actor.vote(trackId: targetTrack.id, voteType: voteType);
        }
        await _settle();

        for (var offset = 0; offset < 5; offset++) {
          final actor = actors[(wave + offset) % actors.length];
          await actor.vote(
            trackId: tracks[startIndex + offset].id,
            voteType: VoteType.none,
          );
          await actor.vote(
            trackId: tracks[startIndex + offset].id,
            voteType: VoteType.like,
          );
        }
        await _settle();

        final roomAfterVotes = host.room!;
        final expectedQueueLength = 5 * (wave + 1);
        expect(roomAfterVotes.queue.length, expectedQueueLength);
        for (final item in roomAfterVotes.queue) {
          expect(item.score, inInclusiveRange(-31, 31));
        }

        final topTrackBeforePlay = roomAfterVotes.queue.first.track.id;
        final intentBeforeGuestPlay = host.room!.playbackIntent;
        await guests[wave].playTopSong();
        await _settle();
        expect(host.room!.playbackIntent.type, intentBeforeGuestPlay.type);
        expect(
          host.room!.playbackIntent.trackId,
          intentBeforeGuestPlay.trackId,
        );

        await host.playTopSong();
        await _settle();
        expect(
          host.room!.playbackIntent.type,
          RoomPlaybackIntentType.playTrack,
        );
        expect(host.room!.playbackIntent.trackId, topTrackBeforePlay);
        expect(host.room!.desiredNowPlayingTrackId, topTrackBeforePlay);
        expect(host.nowPlayingTitle, isNull);
        expect(
          host.room!.queue.any((item) => item.track.id == topTrackBeforePlay),
          isTrue,
        );

        await host.pauseOrResume();
        await _settle();
        expect(host.room!.playbackIntent.type, RoomPlaybackIntentType.pause);
        expect(host.room!.isPaused, isFalse);
        await host.pauseOrResume();
        await _settle();
        expect(host.room!.playbackIntent.type, RoomPlaybackIntentType.pause);
        expect(host.room!.isPaused, isFalse);
      }

      for (var index = 0; index < 5; index++) {
        await host.kickParticipant('guest-$index');
      }
      await _settle();
      expect(host.room!.participantCount, 26);

      await host.closeRoom();
      await _settle();

      expect(host.room!.isClosed, isTrue);
      for (final guest in guests.skip(5)) {
        expect(guest.room!.isClosed, isTrue);
      }
    },
  );
}

Future<void> _settle() async {
  await Future<void>.delayed(const Duration(milliseconds: 20));
}
