// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:party_queue_app/src/features/party/application/party_room_controller.dart';
import 'package:party_queue_app/src/features/party/data/party_room_repository.dart';
import 'package:party_queue_app/src/features/party/domain/models/room_playback_intent.dart';
import 'package:party_queue_app/src/features/party/domain/models/room_settings.dart';
import 'package:party_queue_app/src/features/party/domain/models/user_profile.dart';
import 'package:party_queue_app/src/features/party/domain/models/vote_type.dart';
import 'test_support/test_spotify_harness.dart';

void main() {
  group('party room isolation repro', () {
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

    Future<void> cleanup(String label) async {
      print(
        '[$label] before dispose listeners=${repository.activeListenerCount} controllers=${createdControllers.length}',
      );
      for (final controller in createdControllers) {
        controller.dispose();
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
      print(
        '[$label] after controller dispose listeners=${repository.activeListenerCount}',
      );
      await repository.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      print(
        '[$label] after repository dispose listeners=${repository.activeListenerCount}',
      );
      harness.dispose();
    }

    setUp(() async {
      repository = InMemoryPartyRoomRepository();
      harness = await TestSpotifyHarness.ready(
        catalogService: LargeCatalogService(trackCount: 20),
      );
      createdControllers.clear();
    });

    tearDown(() async {
      await cleanup('tearDown');
    });

    test('minimal: host create and dispose', () async {
      print('[minimal] arrange');
      final host = createController();
      await host.createRoom(
        host: const UserProfile(
          id: 'host-1',
          displayName: 'Host',
          isHost: true,
        ),
        settings: const RoomSettings(),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      print('[minimal] assert');
      expect(host.room, isNotNull);
      expect(repository.activeListenerCount, 1);
    });

    test('join only: host plus one guest', () async {
      print('[join] arrange');
      final host = createController();
      final guest = createController();
      await host.createRoom(
        host: const UserProfile(
          id: 'host-1',
          displayName: 'Host',
          isHost: true,
        ),
        settings: const RoomSettings(maxParticipants: 5),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      print('[join] act');
      final joined = await guest.joinRoom(
        code: host.room!.code,
        user: const UserProfile(id: 'guest-1', displayName: 'Gast 1'),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      print('[join] assert');
      expect(joined, isTrue);
      expect(host.room!.participantCount, 2);
      expect(repository.activeListenerCount, 2);
    });

    test('small wave: host plus three guests with one add', () async {
      print('[small-wave] arrange');
      final host = createController();
      final guests = List<PartyRoomController>.generate(
        3,
        (_) => createController(),
      );
      await host.createRoom(
        host: const UserProfile(
          id: 'host-1',
          displayName: 'Host',
          isHost: true,
        ),
        settings: const RoomSettings(maxParticipants: 10),
      );
      for (var index = 0; index < guests.length; index++) {
        await guests[index].joinRoom(
          code: host.room!.code,
          user: UserProfile(id: 'guest-$index', displayName: 'Gast $index'),
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
      print('[small-wave] act');
      final tracks = await host.search('');
      await guests.first.addTrack(tracks.first);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      print('[small-wave] assert');
      expect(host.room!.participantCount, 4);
      expect(host.room!.queue.length, 1);
      expect(repository.activeListenerCount, 4);
    });

    test('medium wave: host plus three guests with vote and play', () async {
      print('[medium-wave] arrange');
      final host = createController();
      final guests = List<PartyRoomController>.generate(
        3,
        (_) => createController(),
      );
      await host.createRoom(
        host: const UserProfile(
          id: 'host-1',
          displayName: 'Host',
          isHost: true,
        ),
        settings: const RoomSettings(maxParticipants: 10, cooldownMinutes: 5),
      );
      for (var index = 0; index < guests.length; index++) {
        await guests[index].joinRoom(
          code: host.room!.code,
          user: UserProfile(id: 'guest-$index', displayName: 'Gast $index'),
        );
      }
      final tracks = await host.search('');
      await host.addTrack(tracks[0]);
      await guests[0].addTrack(tracks[1]);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      print('[medium-wave] act');
      await host.vote(trackId: tracks[0].id, voteType: VoteType.like);
      await guests[0].vote(trackId: tracks[0].id, voteType: VoteType.like);
      await guests[1].vote(trackId: tracks[1].id, voteType: VoteType.dislike);
      await host.playTopSong();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      print('[medium-wave] assert');
      expect(host.room!.playbackIntent.type, RoomPlaybackIntentType.playTrack);
      expect(host.room!.playbackIntent.trackId, tracks[0].id);
      expect(host.room!.desiredNowPlayingTrackId, tracks[0].id);
      expect(host.room!.nowPlayingTrackId, isNull);
      expect(host.nowPlayingTitle, isNull);
      expect(repository.activeListenerCount, 4);
    });
  });
}
