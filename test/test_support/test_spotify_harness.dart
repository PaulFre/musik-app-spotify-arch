import 'package:party_queue_app/src/features/party/domain/models/spotify_track.dart';
import 'package:party_queue_app/src/features/spotify/application/playback_orchestrator.dart';
import 'package:party_queue_app/src/features/spotify/application/spotify_connection_controller.dart';
import 'package:party_queue_app/src/features/spotify/domain/spotify_auth_service.dart';
import 'package:party_queue_app/src/features/spotify/domain/spotify_catalog_service.dart';
import 'package:party_queue_app/src/features/spotify/domain/spotify_playback_service.dart';

class TestSpotifyHarness {
  TestSpotifyHarness({
    required this.catalogService,
    required this.connectionController,
    required this.playbackOrchestrator,
  });

  final SpotifyCatalogService catalogService;
  final SpotifyConnectionController connectionController;
  final PlaybackOrchestrator playbackOrchestrator;

  static Future<TestSpotifyHarness> ready({
    SpotifyCatalogService? catalogService,
  }) async {
    final connectionController = SpotifyConnectionController(
      authService: FakeSpotifyAuthService(),
      playbackService: FakeSpotifyPlaybackService(),
    );
    final orchestrator = PlaybackOrchestrator(
      connectionController: connectionController,
    );
    final readyHarness = TestSpotifyHarness(
      catalogService: catalogService ?? FakeSpotifyCatalogService(),
      connectionController: connectionController,
      playbackOrchestrator: orchestrator,
    );
    await readyHarness.connectionController.connectHost();
    final devices = readyHarness.connectionController.playbackState.availableDevices;
    if (devices.isNotEmpty) {
      await readyHarness.connectionController.selectDevice(devices.first.id);
    }
    return readyHarness;
  }

  void dispose() {
    playbackOrchestrator.dispose();
    connectionController.dispose();
  }
}

class LargeCatalogService implements SpotifyCatalogService {
  LargeCatalogService({required int trackCount})
    : _catalog = List<SpotifyTrack>.generate(
        trackCount,
        (index) => SpotifyTrack(
          id: 'track-$index',
          uri: 'spotify:track:track-$index',
          title: 'Track $index',
          artist: 'Artist ${index % 7}',
        ),
      );

  final List<SpotifyTrack> _catalog;

  @override
  Future<List<SpotifyTrack>> searchTracks(String query) async {
    if (query.trim().isEmpty) {
      return _catalog;
    }
    final normalized = query.toLowerCase();
    return _catalog
        .where(
          (track) =>
              track.title.toLowerCase().contains(normalized) ||
              track.artist.toLowerCase().contains(normalized),
        )
        .toList();
  }
}
