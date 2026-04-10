import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
  });
}
