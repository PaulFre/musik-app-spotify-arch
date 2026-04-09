import 'dart:async';

import 'package:party_queue_app/src/features/party/domain/models/party_room.dart';

abstract class PartyRoomRepository {
  Stream<PartyRoom?> watchRoom(String code);
  PartyRoom? readRoom(String code);
  Future<void> saveRoom(PartyRoom room);
  Future<void> closeRoom(String code);
}

class InMemoryPartyRoomRepository implements PartyRoomRepository {
  final Map<String, PartyRoom> _rooms = <String, PartyRoom>{};
  final Map<String, StreamController<PartyRoom?>> _controllers =
      <String, StreamController<PartyRoom?>>{};
  final Map<String, int> _activeListenersByCode = <String, int>{};
  bool _isDisposed = false;

  @override
  Stream<PartyRoom?> watchRoom(String code) {
    if (_isDisposed) {
      return const Stream<PartyRoom?>.empty();
    }
    final updates = _controllers.putIfAbsent(
      code,
      () => StreamController<PartyRoom?>.broadcast(sync: true),
    );
    return Stream<PartyRoom?>.multi((controller) {
      _activeListenersByCode.update(
        code,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
      controller.add(_rooms[code]);
      final subscription = updates.stream.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onCancel = () async {
        await subscription.cancel();
        final remaining = (_activeListenersByCode[code] ?? 1) - 1;
        if (remaining <= 0) {
          _activeListenersByCode.remove(code);
        } else {
          _activeListenersByCode[code] = remaining;
        }
      };
    });
  }

  @override
  PartyRoom? readRoom(String code) => _rooms[code];

  @override
  Future<void> saveRoom(PartyRoom room) async {
    if (_isDisposed) {
      return;
    }
    _rooms[room.code] = room;
    _controllers[room.code]?.add(room);
  }

  @override
  Future<void> closeRoom(String code) async {
    if (_isDisposed) {
      return;
    }
    final existing = _rooms[code];
    if (existing == null) {
      return;
    }
    final closed = existing.copyWith(closedAt: DateTime.now());
    _rooms[code] = closed;
    _controllers[code]?.add(closed);
  }

  int get activeListenerCount =>
      _activeListenersByCode.values.fold(0, (sum, count) => sum + count);

  Future<void> dispose() async {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    final controllers = _controllers.values.toList();
    _controllers.clear();
    _rooms.clear();
    _activeListenersByCode.clear();
    for (final controller in controllers) {
      await controller.close();
    }
  }
}
