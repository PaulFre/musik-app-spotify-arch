class SpotifyConnectionState {
  const SpotifyConnectionState({
    this.spotifyConnected = false,
    this.spotifyUserId,
    this.displayName,
    this.accountProduct,
    this.premiumConfirmed = false,
    this.grantedScopes = const <String>[],
    this.accessTokenExpiresAt,
    this.errorCode,
    this.errorMessage,
  });

  final bool spotifyConnected;
  final String? spotifyUserId;
  final String? displayName;
  final String? accountProduct;
  final bool premiumConfirmed;
  final List<String> grantedScopes;
  final DateTime? accessTokenExpiresAt;
  final String? errorCode;
  final String? errorMessage;

  SpotifyConnectionState copyWith({
    bool? spotifyConnected,
    String? spotifyUserId,
    String? displayName,
    String? accountProduct,
    bool? premiumConfirmed,
    List<String>? grantedScopes,
    DateTime? accessTokenExpiresAt,
    String? errorCode,
    String? errorMessage,
  }) {
    return SpotifyConnectionState(
      spotifyConnected: spotifyConnected ?? this.spotifyConnected,
      spotifyUserId: spotifyUserId ?? this.spotifyUserId,
      displayName: displayName ?? this.displayName,
      accountProduct: accountProduct ?? this.accountProduct,
      premiumConfirmed: premiumConfirmed ?? this.premiumConfirmed,
      grantedScopes: grantedScopes ?? this.grantedScopes,
      accessTokenExpiresAt: accessTokenExpiresAt ?? this.accessTokenExpiresAt,
      errorCode: errorCode,
      errorMessage: errorMessage,
    );
  }
}
