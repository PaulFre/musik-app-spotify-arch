import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_queue_app/src/app/app.dart';
import 'package:party_queue_app/src/features/party/data/host_flow_resume_store.dart';
import 'package:party_queue_app/src/features/party/presentation/host_room_screen.dart';
import 'package:party_queue_app/src/features/settings/application/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('shows home screen actions', (WidgetTester tester) async {
    await tester.pumpWidget(const PartyQueueApp());
    await tester.pump();
    expect(find.text('Raum hosten'), findsOneWidget);
    expect(find.text('Raum beitreten'), findsOneWidget);
  });

  testWidgets('restores pending host flow after session restore completes', (
    WidgetTester tester,
  ) async {
    await HostFlowResumeStore.markPendingHostSetup();

    await tester.pumpWidget(const PartyQueueApp());
    await tester.pump();
    expect(find.text('Raum hosten'), findsNothing);
    expect(find.text('Raum beitreten'), findsNothing);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(find.byType(HostRoomScreen), findsOneWidget);
    expect(find.text('Spotify-Host Setup'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('party.host_setup.pending_resume'), isNull);
  });

  test('settings controller persists and restores theme mode', () async {
    final controller = SettingsController();

    await controller.setThemeMode(ThemeMode.dark);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('settings.theme_mode'), 'dark');

    final restoredController = SettingsController();
    await restoredController.restore();

    expect(restoredController.themeMode, ThemeMode.dark);
  });

  test(
    'settings controller migrates legacy system theme mode to light',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'settings.theme_mode': 'system',
      });

      final controller = SettingsController();
      await controller.restore();

      expect(controller.themeMode, ThemeMode.light);
    },
  );

  test('settings controller persists and restores locale', () async {
    final controller = SettingsController();

    await controller.setLocale(const Locale('en'));

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('settings.locale'), 'en');

    final restoredController = SettingsController();
    await restoredController.restore();

    expect(restoredController.locale, const Locale('en'));
  });

  testWidgets('home screen texts switch to english for saved locale', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'settings.locale': 'en',
    });

    await tester.pumpWidget(const PartyQueueApp());
    await tester.pump();

    expect(find.text('Host room'), findsOneWidget);
    expect(find.text('Join room'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Raum hosten'), findsNothing);
  });

  testWidgets('settings language switch updates visible ui texts to english', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const PartyQueueApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Einstellungen'));
    await tester.pumpAndSettle();

    expect(find.text('Sprache'), findsOneWidget);

    await tester.tap(find.text('EN'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Sprache'), findsNothing);
  });
}
