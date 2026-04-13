import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_queue_app/src/app/services.dart';
import 'package:party_queue_app/src/features/party/domain/models/party_room.dart';
import 'package:party_queue_app/src/features/party/domain/models/room_settings.dart';
import 'package:party_queue_app/src/features/party/domain/models/user_profile.dart';
import 'package:party_queue_app/src/features/party/presentation/join_room_screen.dart';

void main() {
  testWidgets('join screen prefills detected invite code', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: JoinRoomScreen(initialJoinInput: 'AB12CD')),
    );

    await tester.pump();

    expect(find.text('AB12CD'), findsOneWidget);
    expect(find.text('Raumcode oder Link'), findsOneWidget);
    expect(find.text('Passwort für privaten Raum'), findsOneWidget);
  });

  testWidgets('join screen lists only public rooms', (
    WidgetTester tester,
  ) async {
    const uniquePublicCode = 'PUB123';
    const uniquePrivateCode = 'PRV123';

    await Services.partyRoomRepository.saveRoom(
      PartyRoom(
        code: uniquePublicCode,
        hostUserId: 'host-public',
        settings: const RoomSettings(isPublic: true),
        createdAt: DateTime.now(),
        participants: const <String, UserProfile>{
          'host-public': UserProfile(
            id: 'host-public',
            displayName: 'Public Host',
            isHost: true,
          ),
        },
      ),
    );
    await Services.partyRoomRepository.saveRoom(
      PartyRoom(
        code: uniquePrivateCode,
        hostUserId: 'host-private',
        settings: const RoomSettings(
          isPublic: false,
          roomPassword: 'secret123',
        ),
        createdAt: DateTime.now().add(const Duration(milliseconds: 1)),
        participants: const <String, UserProfile>{
          'host-private': UserProfile(
            id: 'host-private',
            displayName: 'Private Host',
            isHost: true,
          ),
        },
      ),
    );

    await tester.pumpWidget(const MaterialApp(home: JoinRoomScreen()));
    await tester.pump();

    expect(find.text('Öffentliche Räume'), findsOneWidget);
    expect(find.text('Public Host'), findsOneWidget);
    expect(find.textContaining(uniquePublicCode), findsOneWidget);
    expect(find.text('Private Host'), findsNothing);
    expect(find.textContaining(uniquePrivateCode), findsNothing);
  });
}
