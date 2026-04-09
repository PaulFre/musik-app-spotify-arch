import 'package:flutter_test/flutter_test.dart';
import 'package:party_queue_app/src/features/party/application/party_room_controller.dart';
import 'package:party_queue_app/src/features/party/data/party_room_repository.dart';
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
    final controller = PartyRoomController(
      repository: InMemoryPartyRoomRepository(),
      catalogService: harness.catalogService,
      playbackOrchestrator: harness.playbackOrchestrator,
      spotifyConnectionController: harness.connectionController,
    );

    await controller.createRoom(
      host: const UserProfile(id: 'host-1', displayName: 'Host', isHost: true),
      settings: const RoomSettings(cooldownMinutes: 15),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final results = await controller.search('brightside');
    await controller.addTrack(results.first);
    await controller.addTrack(results.first);
    expect(controller.error, isNotNull);

    await controller.vote(trackId: results.first.id, voteType: VoteType.like);
    expect(controller.room!.queue.first.score, 1);

    await controller.vote(trackId: results.first.id, voteType: VoteType.like);
    expect(controller.room!.queue.first.score, 0);

    controller.dispose();
    harness.dispose();
  });
}
