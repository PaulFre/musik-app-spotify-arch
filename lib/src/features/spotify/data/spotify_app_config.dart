class SpotifyAppConfig {
  const SpotifyAppConfig({
    required this.clientId,
    required this.redirectUri,
    required this.scopes,
    this.accountsBaseUrl = 'https://accounts.spotify.com',
    this.apiBaseUrl = 'https://api.spotify.com/v1',
    this.primaryPlatform = 'web',
  });

  final String clientId;
  final String redirectUri;
  final List<String> scopes;
  final String accountsBaseUrl;
  final String apiBaseUrl;
  final String primaryPlatform;

  bool get isConfigured =>
      clientId.trim().isNotEmpty && redirectUri.trim().isNotEmpty;

  factory SpotifyAppConfig.fromEnvironment() {
    return SpotifyAppConfig(
      clientId: const String.fromEnvironment('SPOTIFY_CLIENT_ID'),
      redirectUri: const String.fromEnvironment('SPOTIFY_REDIRECT_URI'),
      scopes: const <String>[
        'user-read-private',
        'user-modify-playback-state',
        'user-read-playback-state',
        'user-read-currently-playing',
      ],
    );
  }
}
