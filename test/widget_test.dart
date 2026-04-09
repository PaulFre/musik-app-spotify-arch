import 'package:flutter_test/flutter_test.dart';
import 'package:party_queue_app/src/app/app.dart';

void main() {
  testWidgets('shows home screen actions', (WidgetTester tester) async {
    await tester.pumpWidget(const PartyQueueApp());
    expect(find.text('Raum hosten'), findsOneWidget);
    expect(find.text('Raum beitreten'), findsOneWidget);
  });
}
