class SpotifyTrack {
  const SpotifyTrack({
    required this.id,
    this.uri,
    required this.title,
    required this.artist,
  });

  final String id;
  final String? uri;
  final String title;
  final String artist;
}
