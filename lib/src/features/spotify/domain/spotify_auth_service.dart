import 'package:party_queue_app/src/features/spotify/domain/models/spotify_connection_state.dart';

abstract class SpotifyAuthService {
  Future<SpotifyConnectionState> connect();

  Future<SpotifyConnectionState> restoreSession();

  Future<String?> getValidAccessToken();

  Future<SpotifyConnectionState> disconnect();
}

class FakeSpotifyAuthService implements SpotifyAuthService {
  SpotifyConnectionState _state = const SpotifyConnectionState();
  String? _token;

  @override
  Future<SpotifyConnectionState> connect() async {
    _state = const SpotifyConnectionState(
      spotifyConnected: true,
      spotifyUserId: 'spotify-host-1',
      displayName: 'Demo Host',
      accountProduct: 'premium',
      premiumConfirmed: true,
      grantedScopes: <String>[
        'user-read-private',
        'user-modify-playback-state',
        'user-read-playback-state',
        'user-read-currently-playing',
      ],
      accessTokenExpiresAt: null,
    );
    _token = 'fake-access-token';
    return _state;
  }

  @override
  Future<SpotifyConnectionState> disconnect() async {
    _state = const SpotifyConnectionState();
    _token = null;
    return _state;
  }

  @override
  Future<String?> getValidAccessToken() async {
    return _token;
  }

  @override
  Future<SpotifyConnectionState> restoreSession() async {
    return _state;
  }
}
