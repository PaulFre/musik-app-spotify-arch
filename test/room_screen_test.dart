import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_queue_app/src/features/party/application/party_room_controller.dart';
import 'package:party_queue_app/src/features/party/data/party_room_repository.dart';
import 'package:party_queue_app/src/features/party/domain/models/room_settings.dart';
import 'package:party_queue_app/src/features/party/domain/models/user_profile.dart';
import 'package:party_queue_app/src/features/party/presentation/room_screen.dart';
import 'package:party_queue_app/src/features/spotify/application/playback_orchestrator.dart';
import 'package:party_queue_app/src/features/spotify/application/room_playback_intent_processor.dart';
import 'package:party_queue_app/src/features/spotify/application/spotify_connection_controller.dart';
import 'package:party_queue_app/src/features/spotify/domain/spotify_auth_service.dart';
import 'package:party_queue_app/src/features/spotify/domain/spotify_catalog_service.dart';
import 'package:party_queue_app/src/features/spotify/domain/spotify_playback_service.dart';

void main() {
  testWidgets('host room screen shows host menu entries', (
    WidgetTester tester,
  ) async {
    final repository = InMemoryPartyRoomRepository();
    final connectionController = SpotifyConnectionController(
      authService: FakeSpotifyAuthService(),
      playbackService: FakeSpotifyPlaybackService(),
    );
    final playbackOrchestrator = PlaybackOrchestrator(
      connectionController: connectionController,
    );
    final roomPlaybackIntentProcessor = _NoopRoomPlaybackIntentProcessor(
      repository: repository,
      playbackOrchestrator: playbackOrchestrator,
    );
    final controller = PartyRoomController(
      repository: repository,
      catalogService: FakeSpotifyCatalogService(),
      playbackOrchestrator: playbackOrchestrator,
      spotifyConnectionController: connectionController,
      roomPlaybackIntentProcessor: roomPlaybackIntentProcessor,
    );

    await controller.createRoom(
      host: const UserProfile(id: 'host-1', displayName: 'Host', isHost: true),
      settings: const RoomSettings(),
    );

    await tester.pumpWidget(
      MaterialApp(home: RoomScreen(controller: controller)),
    );
    await tester.pump();

    expect(find.byTooltip('Host-Menue'), findsOneWidget);
    final popupMenuFinder = find.byWidgetPredicate(
      (widget) => widget is PopupMenuButton,
      description: 'PopupMenuButton',
    );
    expect(popupMenuFinder, findsOneWidget);

    final popupMenu = tester.widget<PopupMenuButton<dynamic>>(popupMenuFinder);
    final menuEntries = popupMenu.itemBuilder(tester.element(popupMenuFinder));

    expect(menuEntries.whereType<PopupMenuItem<dynamic>>().length, 5);
    expect(find.text('Einladen'), findsNothing);
    expect(
      menuEntries.whereType<PopupMenuItem<dynamic>>().any(
        (entry) => (entry.child as Text).data == 'Einladen',
      ),
      isTrue,
    );
    expect(
      menuEntries.whereType<PopupMenuItem<dynamic>>().any(
        (entry) => (entry.child as Text).data == 'Playlist exportieren',
      ),
      isTrue,
    );
    expect(
      menuEntries.whereType<PopupMenuItem<dynamic>>().any(
        (entry) => (entry.child as Text).data == 'Gaeste',
      ),
      isTrue,
    );
    expect(
      menuEntries.whereType<PopupMenuItem<dynamic>>().any(
        (entry) => (entry.child as Text).data == 'Einstellungen',
      ),
      isTrue,
    );
    expect(
      menuEntries.whereType<PopupMenuItem<dynamic>>().any(
        (entry) => (entry.child as Text).data == 'Raum schliessen',
      ),
      isTrue,
    );
    expect(menuEntries.whereType<PopupMenuDivider>().length, 1);

    controller.dispose();
    await repository.dispose();
    playbackOrchestrator.dispose();
    connectionController.dispose();
  });

  testWidgets('host menu opens a real guests sheet', (
    WidgetTester tester,
  ) async {
    final repository = InMemoryPartyRoomRepository();
    final connectionController = SpotifyConnectionController(
      authService: FakeSpotifyAuthService(),
      playbackService: FakeSpotifyPlaybackService(),
    );
    final playbackOrchestrator = PlaybackOrchestrator(
      connectionController: connectionController,
    );
    final roomPlaybackIntentProcessor = _NoopRoomPlaybackIntentProcessor(
      repository: repository,
      playbackOrchestrator: playbackOrchestrator,
    );
    final hostController = PartyRoomController(
      repository: repository,
      catalogService: FakeSpotifyCatalogService(),
      playbackOrchestrator: playbackOrchestrator,
      spotifyConnectionController: connectionController,
      roomPlaybackIntentProcessor: roomPlaybackIntentProcessor,
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

    await hostController.createRoom(
      host: const UserProfile(id: 'host-1', displayName: 'Host', isHost: true),
      settings: const RoomSettings(),
    );
    await guestController.joinRoom(
      code: hostController.room!.code,
      user: const UserProfile(id: 'guest-1', displayName: 'Ben'),
    );

    await tester.pumpWidget(
      MaterialApp(home: RoomScreen(controller: hostController)),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('Host-Menue'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Gaeste').last, findsOneWidget);
    await tester.tap(find.text('Gaeste').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('2 Teilnehmer im Raum'), findsOneWidget);
    expect(find.text('Host'), findsAtLeastNWidgets(1));
    expect(find.text('Ben'), findsOneWidget);

    hostController.dispose();
    guestController.dispose();
    await repository.dispose();
    playbackOrchestrator.dispose();
    connectionController.dispose();
  });

  testWidgets('host menu opens room settings sheet', (
    WidgetTester tester,
  ) async {
    final repository = InMemoryPartyRoomRepository();
    final connectionController = SpotifyConnectionController(
      authService: FakeSpotifyAuthService(),
      playbackService: FakeSpotifyPlaybackService(),
    );
    final playbackOrchestrator = PlaybackOrchestrator(
      connectionController: connectionController,
    );
    final controller = PartyRoomController(
      repository: repository,
      catalogService: FakeSpotifyCatalogService(),
      playbackOrchestrator: playbackOrchestrator,
      spotifyConnectionController: connectionController,
      roomPlaybackIntentProcessor: _NoopRoomPlaybackIntentProcessor(
        repository: repository,
        playbackOrchestrator: playbackOrchestrator,
      ),
    );

    await controller.createRoom(
      host: const UserProfile(id: 'host-1', displayName: 'Host', isHost: true),
      settings: const RoomSettings(),
    );

    await tester.pumpWidget(
      MaterialApp(home: RoomScreen(controller: controller)),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('Host-Menue'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Einstellungen').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Raum-Einstellungen'), findsOneWidget);
    expect(find.text('Queue-Limit pro Nutzer: 3'), findsOneWidget);

    controller.dispose();
    await repository.dispose();
    playbackOrchestrator.dispose();
    connectionController.dispose();
  });

  testWidgets('host menu opens playlist export sheet', (
    WidgetTester tester,
  ) async {
    final repository = InMemoryPartyRoomRepository();
    final connectionController = SpotifyConnectionController(
      authService: FakeSpotifyAuthService(),
      playbackService: FakeSpotifyPlaybackService(),
    );
    final playbackOrchestrator = PlaybackOrchestrator(
      connectionController: connectionController,
    );
    final controller = PartyRoomController(
      repository: repository,
      catalogService: FakeSpotifyCatalogService(),
      playbackOrchestrator: playbackOrchestrator,
      spotifyConnectionController: connectionController,
      roomPlaybackIntentProcessor: _NoopRoomPlaybackIntentProcessor(
        repository: repository,
        playbackOrchestrator: playbackOrchestrator,
      ),
    );

    await controller.createRoom(
      host: const UserProfile(id: 'host-1', displayName: 'Host', isHost: true),
      settings: const RoomSettings(),
    );
    final track = (await controller.search('')).first;
    await controller.addTrack(track);

    await tester.pumpWidget(
      MaterialApp(home: RoomScreen(controller: controller)),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('Host-Menue'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Playlist exportieren').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Playlist exportieren'), findsWidgets);
    expect(find.text('Export kopieren'), findsOneWidget);
    expect(find.textContaining('1. '), findsOneWidget);

    controller.dispose();
    await repository.dispose();
    playbackOrchestrator.dispose();
    connectionController.dispose();
  });
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
