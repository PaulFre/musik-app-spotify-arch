import 'package:party_queue_app/src/features/party/data/party_room_repository.dart';
import 'package:party_queue_app/src/features/spotify/application/playback_orchestrator.dart';
import 'package:party_queue_app/src/features/spotify/application/spotify_connection_controller.dart';
import 'package:party_queue_app/src/features/spotify/domain/spotify_auth_service.dart';
import 'package:party_queue_app/src/features/spotify/domain/spotify_catalog_service.dart';
import 'package:party_queue_app/src/features/spotify/domain/spotify_playback_service.dart';

class Services {
  Services._();

  static final PartyRoomRepository partyRoomRepository =
      InMemoryPartyRoomRepository();
  static final SpotifyAuthService spotifyAuthService = FakeSpotifyAuthService();
  static final SpotifyCatalogService spotifyCatalogService =
      FakeSpotifyCatalogService();
  static final SpotifyPlaybackService spotifyPlaybackService =
      FakeSpotifyPlaybackService();
  static final SpotifyConnectionController spotifyConnectionController =
      SpotifyConnectionController(
        authService: spotifyAuthService,
        playbackService: spotifyPlaybackService,
      );
  static final PlaybackOrchestrator playbackOrchestrator =
      PlaybackOrchestrator(
        connectionController: spotifyConnectionController,
      );
}
