import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:party_queue_app/src/features/party/application/party_room_controller.dart';
import 'package:party_queue_app/src/features/party/data/party_room_repository.dart';
import 'package:party_queue_app/src/features/party/domain/models/queue_item.dart';
import 'package:party_queue_app/src/features/party/domain/models/room_settings.dart';
import 'package:party_queue_app/src/features/party/domain/models/spotify_artist_ref.dart';
import 'package:party_queue_app/src/features/party/domain/models/spotify_track.dart';
import 'package:party_queue_app/src/features/party/domain/models/user_profile.dart';
import 'package:party_queue_app/src/features/party/presentation/room_screen.dart';
import 'package:party_queue_app/src/features/spotify/application/playback_orchestrator.dart';
import 'package:party_queue_app/src/features/spotify/application/room_playback_intent_processor.dart';
import 'package:party_queue_app/src/features/spotify/application/spotify_connection_controller.dart';
import 'package:party_queue_app/src/features/spotify/domain/spotify_auth_service.dart';
import 'package:party_queue_app/src/features/spotify/domain/spotify_catalog_service.dart';
import 'package:party_queue_app/src/features/spotify/domain/models/spotify_playback_state.dart';
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

    expect(find.byTooltip('Host-Menü'), findsOneWidget);
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
        (entry) => (entry.child as Text).data == 'Gäste',
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
        (entry) => (entry.child as Text).data == 'Raum schließen',
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

    await tester.tap(find.byTooltip('Host-Menü'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Gäste').last, findsOneWidget);
    await tester.tap(find.text('Gäste').last);
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

    await tester.tap(find.byTooltip('Host-Menü'));
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

    await tester.tap(find.byTooltip('Host-Menü'));
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

  testWidgets('now playing shows title artist progress and duration', (
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

    const track = SpotifyTrack(
      id: 'track-1',
      uri: 'spotify:track:track-1',
      title: 'Now Playing Song',
      artist: 'Now Playing Artist',
    );
    await repository.saveRoom(
      controller.room!.copyWith(
        nowPlayingTrack: track,
        nowPlayingTrackId: track.id,
        nowPlayingAddedByUserId: 'host-1',
      ),
    );
    await tester.pump(const Duration(milliseconds: 20));

    final syncTime = DateTime.now();
    connectionController.applyPlaybackState(
      const SpotifyPlaybackState().copyWith(
        selectedDeviceId: 'device-speaker',
        actualNowPlayingTrackId: track.id,
        actualProgressMs: 70000,
        actualDurationMs: 225000,
        actualIsPaused: false,
        lastSyncedAt: syncTime,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: RoomScreen(controller: controller)),
    );
    await tester.pump();

    expect(find.text('Now Playing Song'), findsOneWidget);
    expect(find.text('Now Playing Artist'), findsOneWidget);
    expect(find.text('Hinzugefügt von: Host'), findsOneWidget);
    expect(find.text('1:10'), findsOneWidget);
    expect(find.text('3:45'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.textContaining('device-speaker'), findsNothing);

    await tester.pump(const Duration(seconds: 2));
    expect(find.text('1:12'), findsOneWidget);

    controller.dispose();
    await repository.dispose();
    playbackOrchestrator.dispose();
    connectionController.dispose();
  });

  testWidgets(
    'now playing shows added-by when current track maps to queue item',
    (WidgetTester tester) async {
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
        host: const UserProfile(
          id: 'host-1',
          displayName: 'Host',
          isHost: true,
        ),
        settings: const RoomSettings(),
      );
      await controller.joinRoom(
        code: controller.room!.code,
        user: const UserProfile(id: 'guest-1', displayName: 'Max'),
      );
      const track = SpotifyTrack(
        id: 'queue-track-1',
        uri: 'spotify:track:queue-track-1',
        title: 'Guest Song',
        artist: 'Guest Artist',
      );
      await repository.saveRoom(
        controller.room!.copyWith(
          queue: <QueueItem>[
            QueueItem(
              track: track,
              addedByUserId: 'guest-1',
              addedAt: DateTime.now(),
            ),
          ],
          nowPlayingTrack: track,
          nowPlayingTrackId: track.id,
          nowPlayingAddedByUserId: 'guest-1',
        ),
      );
      await tester.pump(const Duration(milliseconds: 20));

      await tester.pumpWidget(
        MaterialApp(home: RoomScreen(controller: controller)),
      );
      await tester.pump();

      expect(find.text('Hinzugefügt von: Max'), findsOneWidget);

      controller.dispose();
      await repository.dispose();
      playbackOrchestrator.dispose();
      connectionController.dispose();
    },
  );

  testWidgets(
    'now playing hides added-by when track is not attributable to queue',
    (WidgetTester tester) async {
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
        host: const UserProfile(
          id: 'host-1',
          displayName: 'Host',
          isHost: true,
        ),
        settings: const RoomSettings(),
      );
      const track = SpotifyTrack(
        id: 'external-track',
        uri: 'spotify:track:external-track',
        title: 'External Song',
        artist: 'External Artist',
      );
      await repository.saveRoom(
        controller.room!.copyWith(
          nowPlayingTrack: track,
          nowPlayingTrackId: track.id,
        ),
      );
      await tester.pump(const Duration(milliseconds: 20));

      await tester.pumpWidget(
        MaterialApp(home: RoomScreen(controller: controller)),
      );
      await tester.pump();

      expect(find.textContaining('Hinzugefügt von:'), findsNothing);

      controller.dispose();
      await repository.dispose();
      playbackOrchestrator.dispose();
      connectionController.dispose();
    },
  );

  testWidgets(
    'suggestions recover after a stale reload and do not stay in loading state',
    (WidgetTester tester) async {
      final repository = InMemoryPartyRoomRepository();
      final connectionController = SpotifyConnectionController(
        authService: FakeSpotifyAuthService(),
        playbackService: FakeSpotifyPlaybackService(),
      );
      final playbackOrchestrator = PlaybackOrchestrator(
        connectionController: connectionController,
      );
      final catalogService = DelayedSuggestionCatalogService();
      final controller = PartyRoomController(
        repository: repository,
        catalogService: catalogService,
        playbackOrchestrator: playbackOrchestrator,
        spotifyConnectionController: connectionController,
        roomPlaybackIntentProcessor: _NoopRoomPlaybackIntentProcessor(
          repository: repository,
          playbackOrchestrator: playbackOrchestrator,
        ),
      );

      await controller.createRoom(
        host: const UserProfile(
          id: 'host-1',
          displayName: 'Host',
          isHost: true,
        ),
        settings: const RoomSettings(),
      );

      await tester.pumpWidget(
        MaterialApp(home: RoomScreen(controller: controller)),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'abc');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();

      catalogService.completeFirstLoad();
      await tester.pump();

      await tester.enterText(find.byType(TextField).first, '');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();

      expect(
        find.text('Keine addbaren Spotify-Treffer gefunden.'),
        findsNothing,
      );
      expect(find.text('Recovered 1'), findsOneWidget);
      expect(find.text('Recovered 2'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      controller.dispose();
      await repository.dispose();
      playbackOrchestrator.dispose();
      connectionController.dispose();
    },
  );

  testWidgets(
    'suggestion reload after context change is scheduled after build',
    (WidgetTester tester) async {
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
        host: const UserProfile(
          id: 'host-1',
          displayName: 'Host',
          isHost: true,
        ),
        settings: const RoomSettings(),
      );

      await tester.pumpWidget(
        MaterialApp(home: RoomScreen(controller: controller)),
      );
      await tester.pump();
      await tester.pump();

      final track = (await controller.search('')).first;
      await controller.addTrack(track);
      await tester.pump();

      expect(tester.takeException(), isNull);

      await tester.pump();
      expect(tester.takeException(), isNull);

      controller.dispose();
      await repository.dispose();
      playbackOrchestrator.dispose();
      connectionController.dispose();
    },
  );

  testWidgets(
    'guest sees excluded artist warning on explicit artist search only',
    (WidgetTester tester) async {
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
        catalogService: ArtistWarningCatalogService(),
        playbackOrchestrator: playbackOrchestrator,
        spotifyConnectionController: connectionController,
        roomPlaybackIntentProcessor: _NoopRoomPlaybackIntentProcessor(
          repository: repository,
          playbackOrchestrator: playbackOrchestrator,
        ),
      );
      final guestController = PartyRoomController(
        repository: repository,
        catalogService: ArtistWarningCatalogService(),
        playbackOrchestrator: playbackOrchestrator,
        spotifyConnectionController: connectionController,
        roomPlaybackIntentProcessor: _NoopRoomPlaybackIntentProcessor(
          repository: repository,
          playbackOrchestrator: playbackOrchestrator,
        ),
      );

      await hostController.createRoom(
        host: const UserProfile(
          id: 'host-1',
          displayName: 'Host',
          isHost: true,
        ),
        settings: const RoomSettings(
          excludedArtists: <SpotifyArtistRef>[
            SpotifyArtistRef(id: 'artist-weeknd', name: 'The Weeknd'),
          ],
        ),
      );
      await guestController.joinRoom(
        code: hostController.room!.code,
        user: const UserProfile(id: 'guest-1', displayName: 'Guest'),
      );

      await tester.pumpWidget(
        MaterialApp(home: RoomScreen(controller: guestController)),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextField).first, 'The Weeknd');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();

      expect(
        find.text('Dieser Interpret wurde vom Host für diesen Raum gesperrt.'),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextField).first, 'Shared Title');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();

      expect(
        find.text('Dieser Interpret wurde vom Host für diesen Raum gesperrt.'),
        findsNothing,
      );
      expect(find.text('Shared Title'), findsOneWidget);

      hostController.dispose();
      guestController.dispose();
      await repository.dispose();
      playbackOrchestrator.dispose();
      connectionController.dispose();
    },
  );

  testWidgets(
    'explicit excluded artist search shows warning together with empty state',
    (WidgetTester tester) async {
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
        catalogService: ArtistWarningCatalogService(),
        playbackOrchestrator: playbackOrchestrator,
        spotifyConnectionController: connectionController,
        roomPlaybackIntentProcessor: _NoopRoomPlaybackIntentProcessor(
          repository: repository,
          playbackOrchestrator: playbackOrchestrator,
        ),
      );

      await controller.createRoom(
        host: const UserProfile(
          id: 'host-1',
          displayName: 'Host',
          isHost: true,
        ),
        settings: const RoomSettings(
          excludedArtists: <SpotifyArtistRef>[
            SpotifyArtistRef(id: 'artist-weeknd', name: 'The Weeknd'),
          ],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(home: RoomScreen(controller: controller)),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextField).first, 'The Weeknd');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();

      expect(
        find.text('Dieser Interpret wurde vom Host für diesen Raum gesperrt.'),
        findsOneWidget,
      );
      expect(
        find.text('Keine addbaren Spotify-Treffer gefunden.'),
        findsOneWidget,
      );

      controller.dispose();
      await repository.dispose();
      playbackOrchestrator.dispose();
      connectionController.dispose();
    },
  );
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

class DelayedSuggestionCatalogService implements SpotifyCatalogService {
  final Completer<List<SpotifyTrack>> _firstLoadCompleter =
      Completer<List<SpotifyTrack>>();
  int _loadSuggestionsCallCount = 0;

  void completeFirstLoad() {
    if (_firstLoadCompleter.isCompleted) {
      return;
    }
    _firstLoadCompleter.complete(const <SpotifyTrack>[
      SpotifyTrack(
        id: 'initial-1',
        uri: 'spotify:track:initial-1',
        title: 'Initial 1',
        artist: 'Artist Initial',
      ),
    ]);
  }

  @override
  Future<List<SpotifyTrack>> loadSuggestions() {
    _loadSuggestionsCallCount += 1;
    if (_loadSuggestionsCallCount == 1) {
      return _firstLoadCompleter.future;
    }
    return Future<List<SpotifyTrack>>.value(const <SpotifyTrack>[
      SpotifyTrack(
        id: 'recovered-1',
        uri: 'spotify:track:recovered-1',
        title: 'Recovered 1',
        artist: 'Artist Recovered',
      ),
      SpotifyTrack(
        id: 'recovered-2',
        uri: 'spotify:track:recovered-2',
        title: 'Recovered 2',
        artist: 'Artist Recovered',
      ),
      SpotifyTrack(
        id: 'recovered-3',
        uri: 'spotify:track:recovered-3',
        title: 'Recovered 3',
        artist: 'Artist Recovered',
      ),
    ]);
  }

  @override
  Future<List<SpotifyTrack>> searchTracks(String query) async {
    return const <SpotifyTrack>[];
  }
}

class ArtistWarningCatalogService implements SpotifyCatalogService {
  @override
  Future<List<SpotifyTrack>> loadSuggestions() async {
    return const <SpotifyTrack>[];
  }

  @override
  Future<List<SpotifyTrack>> searchTracks(String query) async {
    final normalized = query.trim().toLowerCase();
    if (normalized == 'the weeknd') {
      return const <SpotifyTrack>[
        SpotifyTrack(
          id: 'blocked-track',
          uri: 'spotify:track:blocked-track',
          title: 'Blinding Lights',
          artist: 'The Weeknd',
          artistRefs: <SpotifyArtistRef>[
            SpotifyArtistRef(id: 'artist-weeknd', name: 'The Weeknd'),
          ],
        ),
      ];
    }
    if (normalized == 'shared title') {
      return const <SpotifyTrack>[
        SpotifyTrack(
          id: 'blocked-shared',
          uri: 'spotify:track:blocked-shared',
          title: 'Shared Title',
          artist: 'The Weeknd',
          artistRefs: <SpotifyArtistRef>[
            SpotifyArtistRef(id: 'artist-weeknd', name: 'The Weeknd'),
          ],
        ),
        SpotifyTrack(
          id: 'allowed-shared',
          uri: 'spotify:track:allowed-shared',
          title: 'Shared Title',
          artist: 'Allowed Artist',
          artistRefs: <SpotifyArtistRef>[
            SpotifyArtistRef(id: 'artist-allowed', name: 'Allowed Artist'),
          ],
        ),
      ];
    }
    return const <SpotifyTrack>[];
  }
}
