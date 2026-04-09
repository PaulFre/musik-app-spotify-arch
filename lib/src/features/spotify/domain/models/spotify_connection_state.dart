class SpotifyConnectionState {
  const SpotifyConnectionState({
    this.spotifyConnected = false,
    this.spotifyUserId,
    this.displayName,
    this.premiumConfirmed = false,
    this.errorMessage,
  });

  final bool spotifyConnected;
  final String? spotifyUserId;
  final String? displayName;
  final bool premiumConfirmed;
  final String? errorMessage;

  SpotifyConnectionState copyWith({
    bool? spotifyConnected,
    String? spotifyUserId,
    String? displayName,
    bool? premiumConfirmed,
    String? errorMessage,
  }) {
    return SpotifyConnectionState(
      spotifyConnected: spotifyConnected ?? this.spotifyConnected,
      spotifyUserId: spotifyUserId ?? this.spotifyUserId,
      displayName: displayName ?? this.displayName,
      premiumConfirmed: premiumConfirmed ?? this.premiumConfirmed,
      errorMessage: errorMessage,
    );
  }
}
