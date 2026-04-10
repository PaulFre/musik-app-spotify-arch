import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_queue_app/src/features/party/application/party_room_controller.dart';
import 'package:party_queue_app/src/features/party/data/party_room_repository.dart';
import 'package:party_queue_app/src/features/party/domain/models/room_settings.dart';
import 'package:party_queue_app/src/features/party/domain/models/user_profile.dart';
import 'package:party_queue_app/src/features/party/presentation/room_settings_sheet.dart';
import 'package:party_queue_app/src/features/spotify/application/playback_orchestrator.dart';
import 'package:party_queue_app/src/features/spotify/application/room_playback_intent_processor.dart';
import 'package:party_queue_app/src/features/spotify/application/spotify_connection_controller.dart';
import 'package:party_queue_app/src/features/spotify/domain/spotify_auth_service.dart';
import 'package:party_queue_app/src/features/spotify/domain/spotify_catalog_service.dart';
import 'package:party_queue_app/src/features/spotify/domain/spotify_playback_service.dart';

void main() {
  testWidgets('shows current room settings values', (
    WidgetTester tester,
  ) async {
    final bundle = await _buildSettingsBundle();
    await bundle.hostController.createRoom(
      host: const UserProfile(id: 'host-1', displayName: 'Host', isHost: true),
      settings: const RoomSettings(
        cooldownMinutes: 30,
        maxParticipants: 40,
        maxQueuedTracksPerUser: 4,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RoomSettingsSheet(controller: bundle.hostController),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Raum-Einstellungen'), findsOneWidget);
    expect(find.text('30 Minuten Cooldown'), findsOneWidget);
    expect(find.text('Max. Teilnehmer: 40'), findsOneWidget);
    expect(find.text('Queue-Limit pro Nutzer: 4'), findsOneWidget);

    await bundle.dispose();
  });

  testWidgets('host can save changed room limits into real room state', (
    WidgetTester tester,
  ) async {
    final bundle = await _buildSettingsBundle();
    await bundle.hostController.createRoom(
      host: const UserProfile(id: 'host-1', displayName: 'Host', isHost: true),
      settings: const RoomSettings(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RoomSettingsSheet(controller: bundle.hostController),
        ),
      ),
    );
    await tester.pump();

    await tester.drag(find.byType(Slider).at(0), const Offset(200, 0));
    await tester.pump();
    await tester.drag(find.byType(Slider).at(1), const Offset(120, 0));
    await tester.pump();
    await tester.tap(find.text('30 Minuten Cooldown'));
    await tester.pump();
    await tester.tap(find.text('60 Minuten Cooldown').last);
    await tester.pump();
    await tester.tap(find.text('Speichern'));
    await tester.pump();

    expect(bundle.hostController.room!.settings.cooldownMinutes, 60);
    expect(
      bundle.hostController.room!.settings.maxQueuedTracksPerUser,
      greaterThan(3),
    );
    expect(
      bundle.hostController.room!.settings.maxParticipants,
      greaterThan(25),
    );

    await bundle.dispose();
  });

  testWidgets('non-host cannot save room settings', (
    WidgetTester tester,
  ) async {
    final bundle = await _buildSettingsBundle();
    await bundle.hostController.createRoom(
      host: const UserProfile(id: 'host-1', displayName: 'Host', isHost: true),
      settings: const RoomSettings(),
    );
    await bundle.guestController.joinRoom(
      code: bundle.hostController.room!.code,
      user: const UserProfile(id: 'guest-1', displayName: 'Guest'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RoomSettingsSheet(controller: bundle.guestController),
        ),
      ),
    );
    await tester.pump();

    final saveButton = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(saveButton.onPressed, isNull);

    await bundle.dispose();
  });

  testWidgets(
    'renders participant slider safely when room already has 100 participants',
    (WidgetTester tester) async {
      final bundle = await _buildSettingsBundle();
      await bundle.hostController.createRoom(
        host: const UserProfile(
          id: 'host-1',
          displayName: 'Host',
          isHost: true,
        ),
        settings: const RoomSettings(maxParticipants: 100),
      );

      for (var index = 0; index < 99; index++) {
        await bundle.guestController.joinRoom(
          code: bundle.hostController.room!.code,
          user: UserProfile(id: 'guest-$index', displayName: 'Guest $index'),
        );
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RoomSettingsSheet(controller: bundle.hostController),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Max. Teilnehmer: 100'), findsOneWidget);
      final participantSlider = tester.widget<Slider>(
        find.byType(Slider).first,
      );
      expect(participantSlider.min, 100);
      expect(participantSlider.max, 100);
      expect(participantSlider.divisions, isNull);

      await bundle.dispose();
    },
  );
}

Future<_SettingsTestBundle> _buildSettingsBundle() async {
  final repository = InMemoryPartyRoomRepository();
  final connectionController = SpotifyConnectionController(
    authService: FakeSpotifyAuthService(),
    playbackService: FakeSpotifyPlaybackService(),
  );
  final playbackOrchestrator = PlaybackOrchestrator(
    connectionController: connectionController,
  );
  final hostController = PartyRoomController(
    repository: repository,
    catalogService: FakeSpotifyCatalogService(),
    playbackOrchestrator: playbackOrchestrator,
    spotifyConnectionController: connectionController,
    roomPlaybackIntentProcessor: _NoopRoomPlaybackIntentProcessor(
      repository: repository,
      playbackOrchestrator: playbackOrchestrator,
    ),
  );
  final guestController = PartyRoomController(
    repository: repository,
    catalogService: FakeSpotifyCatalogService(),
    playbackOrchestrator: playbackOrchestrator,
    spotifyConnectionController: connectionController,
    roomPlaybackIntentProcessor: _NoopRoomPlaybackIntentProcessor(
      repository: repository,
      playbackOrchestrator: playbackOrchestrator,
    ),
  );
  return _SettingsTestBundle(
    repository: repository,
    connectionController: connectionController,
    playbackOrchestrator: playbackOrchestrator,
    hostController: hostController,
    guestController: guestController,
  );
}

class _SettingsTestBundle {
  _SettingsTestBundle({
    required this.repository,
    required this.connectionController,
    required this.playbackOrchestrator,
    required this.hostController,
    required this.guestController,
  });

  final InMemoryPartyRoomRepository repository;
  final SpotifyConnectionController connectionController;
  final PlaybackOrchestrator playbackOrchestrator;
  final PartyRoomController hostController;
  final PartyRoomController guestController;

  Future<void> dispose() async {
    hostController.dispose();
    guestController.dispose();
    playbackOrchestrator.dispose();
    connectionController.dispose();
    await repository.dispose();
  }
}

class _NoopRoomPlaybackIntentProcessor extends RoomPlaybackIntentProcessor {
  _NoopRoomPlaybackIntentProcessor({
    required super.repository,
    required super.playbackOrchestrator,
  });

  @override
  void start(String code) {}

  @override
  void stop() {}

  @override
  void dispose() {}
}
