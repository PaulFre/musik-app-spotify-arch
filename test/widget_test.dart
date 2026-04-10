import 'package:flutter_test/flutter_test.dart';
import 'package:party_queue_app/src/app/app.dart';
import 'package:party_queue_app/src/features/party/data/host_flow_resume_store.dart';
import 'package:party_queue_app/src/features/party/presentation/host_room_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('shows home screen actions', (WidgetTester tester) async {
    await tester.pumpWidget(const PartyQueueApp());
    expect(find.text('Raum hosten'), findsOneWidget);
    expect(find.text('Raum beitreten'), findsOneWidget);
  });

  testWidgets('restores pending host flow after session restore completes', (
    WidgetTester tester,
  ) async {
    await HostFlowResumeStore.markPendingHostSetup();

    await tester.pumpWidget(const PartyQueueApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(find.byType(HostRoomScreen), findsOneWidget);
    expect(find.text('Spotify-Host Setup'), findsOneWidget);
  });
}
