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

  test('watchPublicRooms only emits open public rooms', () async {
    final publicRoom = PartyRoom(
      code: 'PUB123',
      hostUserId: 'host-public',
      settings: const RoomSettings(isPublic: true),
      createdAt: DateTime(2026, 4, 9, 12),
    );
    final privateRoom = PartyRoom(
      code: 'PRV123',
      hostUserId: 'host-private',
      settings: const RoomSettings(isPublic: false, roomPassword: 'secret123'),
      createdAt: DateTime(2026, 4, 9, 13),
    );

    await repository.saveRoom(publicRoom);
    await repository.saveRoom(privateRoom);

    await expectLater(
      repository.watchPublicRooms(),
      emits(
        predicate((value) {
          return value is List<PartyRoom> &&
              value.length == 1 &&
              value.single.code == 'PUB123';
        }),
      ),
    );
  });
}
