import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_queue_app/src/features/party/presentation/room_invite_sheet.dart';

void main() {
  testWidgets('invite sheet shows link, code and copy actions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RoomInviteSheet(
            roomCode: 'AB12CD',
            inviteLink: Uri(
              scheme: 'https',
              host: 'party.example.dev',
              path: '/join',
              queryParameters: <String, String>{'code': 'AB12CD'},
            ),
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Einladen'), findsOneWidget);
    expect(find.text('Invite-Link'), findsOneWidget);
    expect(find.text('Room-Code'), findsOneWidget);
    expect(find.text('Link kopieren'), findsOneWidget);
    expect(find.text('Code kopieren'), findsOneWidget);
    expect(find.text('AB12CD'), findsOneWidget);
    expect(find.byType(SelectableText), findsNWidgets(2));

    await tester.tap(find.text('Code kopieren'));
    await tester.pump();

    final clipboard = await Clipboard.getData('text/plain');
    expect(clipboard?.text, 'AB12CD');
    expect(find.text('Room-Code kopiert.'), findsOneWidget);
  });
}
