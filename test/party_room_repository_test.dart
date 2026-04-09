import 'package:flutter_test/flutter_test.dart';
import 'package:party_queue_app/src/features/party/data/party_room_repository.dart';
import 'package:party_queue_app/src/features/party/domain/models/party_room.dart';
import 'package:party_queue_app/src/features/party/domain/models/room_settings.dart';

void main() {
  late InMemoryPartyRoomRepository repository;

  setUp(() {
    repository = InMemoryPartyRoomRepository();
  });

  tearDown(() async {
    expect(repository.activeListenerCount, 0);
    await repository.dispose();
  });

  test('watchRoom emits the current snapshot to a new listener', () async {
    final room = PartyRoom(
      code: 'ABC123',
      hostUserId: 'host-1',
      settings: const RoomSettings(),
      createdAt: DateTime(2026, 4, 9, 12),
    );

    await repository.saveRoom(room);

    await expectLater(
      repository.watchRoom('ABC123'),
      emits(
        predicate((value) {
          return value is PartyRoom && value.code == 'ABC123';
        }),
      ),
    );
  });
}
