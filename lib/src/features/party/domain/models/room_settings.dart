import 'package:party_queue_app/src/features/party/domain/models/spotify_artist_ref.dart';
import 'package:party_queue_app/src/features/party/domain/models/spotify_track.dart';

const Object _unset = Object();

class RoomSettings {
  const RoomSettings({
    this.cooldownMinutes = 15,
    this.maxParticipants = 25,
    this.maxQueuedTracksPerUser = 3,
    this.isPublic = false,
    this.roomPassword,
    this.autoCloseMinutes = 120,
    this.excludedTracks = const <SpotifyTrack>[],
    this.excludedArtists = const <SpotifyArtistRef>[],
  });

  final int cooldownMinutes;
  final int maxParticipants;
  final int maxQueuedTracksPerUser;
  final bool isPublic;
  final String? roomPassword;
  final int autoCloseMinutes;
  final List<SpotifyTrack> excludedTracks;
  final List<SpotifyArtistRef> excludedArtists;

  RoomSettings copyWith({
    int? cooldownMinutes,
    int? maxParticipants,
    int? maxQueuedTracksPerUser,
    bool? isPublic,
    Object? roomPassword = _unset,
    int? autoCloseMinutes,
    List<SpotifyTrack>? excludedTracks,
    List<SpotifyArtistRef>? excludedArtists,
  }) {
    return RoomSettings(
      cooldownMinutes: cooldownMinutes ?? this.cooldownMinutes,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      maxQueuedTracksPerUser:
          maxQueuedTracksPerUser ?? this.maxQueuedTracksPerUser,
      isPublic: isPublic ?? this.isPublic,
      roomPassword: roomPassword == _unset
          ? this.roomPassword
          : roomPassword as String?,
      autoCloseMinutes: autoCloseMinutes ?? this.autoCloseMinutes,
      excludedTracks: excludedTracks ?? this.excludedTracks,
      excludedArtists: excludedArtists ?? this.excludedArtists,
    );
  }
}
