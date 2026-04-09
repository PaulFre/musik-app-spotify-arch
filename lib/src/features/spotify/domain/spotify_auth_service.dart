import 'package:party_queue_app/src/features/spotify/domain/models/spotify_connection_state.dart';

abstract class SpotifyAuthService {
  Future<SpotifyConnectionState> connect();

  Future<SpotifyConnectionState> disconnect();
}

class FakeSpotifyAuthService implements SpotifyAuthService {
  SpotifyConnectionState _state = const SpotifyConnectionState();

  @override
  Future<SpotifyConnectionState> connect() async {
    _state = const SpotifyConnectionState(
      spotifyConnected: true,
      spotifyUserId: 'spotify-host-1',
      displayName: 'Demo Host',
      premiumConfirmed: true,
    );
    return _state;
  }

  @override
  Future<SpotifyConnectionState> disconnect() async {
    _state = const SpotifyConnectionState();
    return _state;
  }
}
