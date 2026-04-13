import 'package:party_queue_app/src/features/party/domain/models/spotify_artist_ref.dart';

class SpotifyTrack {
  const SpotifyTrack({
    required this.id,
    this.uri,
    required this.title,
    required this.artist,
    this.artistRefs = const <SpotifyArtistRef>[],
  });

  final String id;
  final String? uri;
  final String title;
  final String artist;
  final List<SpotifyArtistRef> artistRefs;
}
