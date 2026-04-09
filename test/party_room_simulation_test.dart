import 'package:flutter_test/flutter_test.dart';
import 'package:party_queue_app/src/features/party/application/party_room_controller.dart';
import 'package:party_queue_app/src/features/party/data/party_room_repository.dart';
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
    harness = await TestSpotifyHarness.ready();
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

  test('simulates a host and 10 guests interacting in one room', () async {
    final host = createController();

    await host.createRoom(
      host: const UserProfile(id: 'host-1', displayName: 'Host', isHost: true),
      settings: const RoomSettings(cooldownMinutes: 15, maxParticipants: 20),
    );
    await _settle();

    final roomCode = host.room!.code;
    final guests = List<PartyRoomController>.generate(10, (_) => createController());

    for (var index = 0; index < guests.length; index++) {
      final joined = await guests[index].joinRoom(
        code: roomCode,
        user: UserProfile(id: 'guest-$index', displayName: 'Gast $index'),
      );
      expect(joined, isTrue, reason: 'guest-$index should join successfully');
    }
    await _settle();

    expect(host.room!.participantCount, 11);
    for (final guest in guests) {
      expect(guest.room!.participantCount, 11);
    }

    final tracks = await host.search('');
    final contributors = <PartyRoomController>[host, ...guests.take(4)];
    for (var index = 0; index < contributors.length; index++) {
      await contributors[index].addTrack(tracks[index]);
    }
    await _settle();

    expect(host.room!.queue.map((item) => item.track.id).toSet().length, 5);

    await guests[4].addTrack(tracks.first);
    expect(guests[4].error, 'Track already exists in queue.');

    final topTrack = tracks[0];
    final secondTrack = tracks[1];

    for (final controller in <PartyRoomController>[host, ...guests.take(7)]) {
      await controller.vote(trackId: topTrack.id, voteType: VoteType.like);
    }
    for (final controller in guests.skip(7)) {
      await controller.vote(trackId: secondTrack.id, voteType: VoteType.dislike);
    }
    await _settle();

    expect(host.room!.queue.first.track.id, topTrack.id);
    expect(host.room!.queue.first.score, 8);

    await host.playTopSong();
    await _settle();

    expect(host.room!.nowPlayingTrackId, topTrack.id);
    expect(host.nowPlayingTitle, topTrack.title);
    expect(guests.first.nowPlayingTitle, topTrack.title);
    expect(host.room!.queue.every((item) => item.track.id != topTrack.id), isTrue);

    await host.pauseOrResume();
    await _settle();
    expect(host.room!.isPaused, isTrue);

    await host.skipNowPlaying();
    await _settle();
    expect(host.room!.nowPlayingTrackId, isNot(topTrack.id));
    expect(host.nowPlayingTitle, isNotNull);

    await host.closeRoom();
    await _settle();
    expect(host.room!.isClosed, isTrue);
    expect(guests.last.room!.isClosed, isTrue);
  });
}

Future<void> _settle() async {
  await Future<void>.delayed(const Duration(milliseconds: 25));
}
