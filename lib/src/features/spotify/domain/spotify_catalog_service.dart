import 'package:party_queue_app/src/features/party/domain/models/spotify_artist_ref.dart';
import 'package:party_queue_app/src/features/party/domain/models/spotify_track.dart';

abstract class SpotifyCatalogService {
  Future<List<SpotifyTrack>> searchTracks(String query);

  Future<List<SpotifyTrack>> loadSuggestions();
}

class SpotifyCatalogException implements Exception {
  const SpotifyCatalogException({required this.code, required this.message});

  final String code;
  final String message;
}

class FakeSpotifyCatalogService implements SpotifyCatalogService {
  static const List<SpotifyTrack> _catalog = <SpotifyTrack>[
    SpotifyTrack(
      id: '3n3Ppam7vgaVa1iaRUc9Lp',
      uri: 'spotify:track:3n3Ppam7vgaVa1iaRUc9Lp',
      title: 'Mr. Brightside',
      artist: 'The Killers',
      artistRefs: <SpotifyArtistRef>[
        SpotifyArtistRef(id: 'artist-killers', name: 'The Killers'),
      ],
    ),
    SpotifyTrack(
      id: '7ouMYWpwJ422jRcDASZB7P',
      uri: 'spotify:track:7ouMYWpwJ422jRcDASZB7P',
      title: 'Bohemian Rhapsody',
      artist: 'Queen',
      artistRefs: <SpotifyArtistRef>[
        SpotifyArtistRef(id: 'artist-queen', name: 'Queen'),
      ],
    ),
    SpotifyTrack(
      id: '6habFhsOp2NvshLv26DqMb',
      uri: 'spotify:track:6habFhsOp2NvshLv26DqMb',
      title: 'Blinding Lights',
      artist: 'The Weeknd',
      artistRefs: <SpotifyArtistRef>[
        SpotifyArtistRef(id: 'artist-weeknd', name: 'The Weeknd'),
      ],
    ),
    SpotifyTrack(
      id: '2Fxmhks0bxGSBdJ92vM42m',
      uri: 'spotify:track:2Fxmhks0bxGSBdJ92vM42m',
      title: 'bad guy',
      artist: 'Billie Eilish',
      artistRefs: <SpotifyArtistRef>[
        SpotifyArtistRef(id: 'artist-billie', name: 'Billie Eilish'),
      ],
    ),
    SpotifyTrack(
      id: '0VjIjW4GlUZAMYd2vXMi3b',
      uri: 'spotify:track:0VjIjW4GlUZAMYd2vXMi3b',
      title: 'Save Your Tears',
      artist: 'The Weeknd',
      artistRefs: <SpotifyArtistRef>[
        SpotifyArtistRef(id: 'artist-weeknd', name: 'The Weeknd'),
      ],
    ),
  ];

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

  @override
  Future<List<SpotifyTrack>> loadSuggestions() async {
    return _catalog.take(3).toList();
  }
}
