class SpotifyConnectionState {
  const SpotifyConnectionState({
    this.spotifyConnected = false,
    this.spotifyUserId,
    this.displayName,
    this.premiumConfirmed = false,
    this.grantedScopes = const <String>[],
    this.accessTokenExpiresAt,
    this.errorMessage,
  });

  final bool spotifyConnected;
  final String? spotifyUserId;
  final String? displayName;
  final bool premiumConfirmed;
  final List<String> grantedScopes;
  final DateTime? accessTokenExpiresAt;
  final String? errorMessage;

  SpotifyConnectionState copyWith({
    bool? spotifyConnected,
    String? spotifyUserId,
    String? displayName,
    bool? premiumConfirmed,
    List<String>? grantedScopes,
    DateTime? accessTokenExpiresAt,
    String? errorMessage,
  }) {
    return SpotifyConnectionState(
      spotifyConnected: spotifyConnected ?? this.spotifyConnected,
      spotifyUserId: spotifyUserId ?? this.spotifyUserId,
      displayName: displayName ?? this.displayName,
      premiumConfirmed: premiumConfirmed ?? this.premiumConfirmed,
      grantedScopes: grantedScopes ?? this.grantedScopes,
      accessTokenExpiresAt: accessTokenExpiresAt ?? this.accessTokenExpiresAt,
      errorMessage: errorMessage,
    );
  }
}
