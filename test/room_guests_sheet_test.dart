import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_queue_app/src/features/party/application/party_room_controller.dart';
import 'package:party_queue_app/src/features/party/data/party_room_repository.dart';
import 'package:party_queue_app/src/features/party/domain/models/room_settings.dart';
import 'package:party_queue_app/src/features/party/domain/models/user_profile.dart';
import 'package:party_queue_app/src/features/party/presentation/room_guests_sheet.dart';
import 'package:party_queue_app/src/features/spotify/application/playback_orchestrator.dart';
import 'package:party_queue_app/src/features/spotify/application/room_playback_intent_processor.dart';
import 'package:party_queue_app/src/features/spotify/application/spotify_connection_controller.dart';
import 'package:party_queue_app/src/features/spotify/domain/spotify_auth_service.dart';
import 'package:party_queue_app/src/features/spotify/domain/spotify_catalog_service.dart';
import 'package:party_queue_app/src/features/spotify/domain/spotify_playback_service.dart';

void main() {
  testWidgets(
    'shows participants from live room data with host and current user markers',
    (WidgetTester tester) async {
      final bundle = await _buildRoomBundle();

      await bundle.hostController.createRoom(
        host: const UserProfile(
          id: 'host-1',
          displayName: 'Anna',
          isHost: true,
        ),
        settings: const RoomSettings(),
      );
      await bundle.guestControllerA.joinRoom(
        code: bundle.hostController.room!.code,
        user: const UserProfile(id: 'guest-2', displayName: 'Ben'),
      );
      await bundle.guestControllerB.joinRoom(
        code: bundle.hostController.room!.code,
        user: const UserProfile(id: 'guest-1', displayName: 'Chris'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RoomGuestsSheet(controller: bundle.guestControllerB),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Gaeste'), findsOneWidget);
      expect(find.text('3 Teilnehmer im Raum'), findsOneWidget);
      expect(find.text('Anna'), findsOneWidget);
      expect(find.text('Ben'), findsOneWidget);
      expect(find.text('Chris'), findsOneWidget);
      expect(find.text('Host'), findsOneWidget);
      expect(find.text('Du'), findsOneWidget);
      expect(find.byTooltip('Gast entfernen'), findsNothing);

      final annaTopLeft = tester.getTopLeft(find.text('Anna'));
      final benTopLeft = tester.getTopLeft(find.text('Ben'));
      final chrisTopLeft = tester.getTopLeft(find.text('Chris'));
      expect(annaTopLeft.dy, lessThan(benTopLeft.dy));
      expect(benTopLeft.dy, lessThan(chrisTopLeft.dy));

      await bundle.dispose();
    },
  );

  testWidgets('shows helpful empty-state copy when only the host is present', (
    WidgetTester tester,
  ) async {
    final bundle = await _buildRoomBundle();
    await bundle.hostController.createRoom(
      host: const UserProfile(id: 'host-1', displayName: 'Host', isHost: true),
      settings: const RoomSettings(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RoomGuestsSheet(controller: bundle.hostController),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Noch keine weiteren Gaeste im Raum.'), findsOneWidget);
    expect(find.byTooltip('Gast entfernen'), findsNothing);

    await bundle.dispose();
  });

  testWidgets('removes kicked guest from the open sheet immediately', (
    WidgetTester tester,
  ) async {
    final bundle = await _buildRoomBundle();
    await bundle.hostController.createRoom(
      host: const UserProfile(id: 'host-1', displayName: 'Host', isHost: true),
      settings: const RoomSettings(),
    );
    await bundle.guestControllerA.joinRoom(
      code: bundle.hostController.room!.code,
      user: const UserProfile(id: 'guest-1', displayName: 'Ben'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RoomGuestsSheet(controller: bundle.hostController),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Ben'), findsOneWidget);
    await tester.tap(find.byTooltip('Gast entfernen'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Ben'), findsNothing);
    expect(find.text('Ben entfernt.'), findsOneWidget);

    await bundle.dispose();
  });
}

Future<_RoomTestBundle> _buildRoomBundle() async {
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
  final guestControllerA = PartyRoomController(
    repository: repository,
    catalogService: FakeSpotifyCatalogService(),
    playbackOrchestrator: playbackOrchestrator,
    spotifyConnectionController: connectionController,
    roomPlaybackIntentProcessor: _NoopRoomPlaybackIntentProcessor(
      repository: repository,
      playbackOrchestrator: playbackOrchestrator,
    ),
  );
  final guestControllerB = PartyRoomController(
    repository: repository,
    catalogService: FakeSpotifyCatalogService(),
    playbackOrchestrator: playbackOrchestrator,
    spotifyConnectionController: connectionController,
    roomPlaybackIntentProcessor: _NoopRoomPlaybackIntentProcessor(
      repository: repository,
      playbackOrchestrator: playbackOrchestrator,
    ),
  );
  return _RoomTestBundle(
    repository: repository,
    connectionController: connectionController,
    playbackOrchestrator: playbackOrchestrator,
    hostController: hostController,
    guestControllerA: guestControllerA,
    guestControllerB: guestControllerB,
  );
}

class _RoomTestBundle {
  _RoomTestBundle({
    required this.repository,
    required this.connectionController,
    required this.playbackOrchestrator,
    required this.hostController,
    required this.guestControllerA,
    required this.guestControllerB,
  });

  final InMemoryPartyRoomRepository repository;
  final SpotifyConnectionController connectionController;
  final PlaybackOrchestrator playbackOrchestrator;
  final PartyRoomController hostController;
  final PartyRoomController guestControllerA;
  final PartyRoomController guestControllerB;

  Future<void> dispose() async {
    hostController.dispose();
    guestControllerA.dispose();
    guestControllerB.dispose();
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
