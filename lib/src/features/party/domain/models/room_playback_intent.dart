enum RoomPlaybackIntentType { none, playTrack, pause, resume, skip, closeRoom }

class RoomPlaybackIntent {
  const RoomPlaybackIntent._({required this.type, this.trackId});

  const RoomPlaybackIntent.none() : this._(type: RoomPlaybackIntentType.none);

  const RoomPlaybackIntent.playTrack(String trackId)
    : this._(type: RoomPlaybackIntentType.playTrack, trackId: trackId);

  const RoomPlaybackIntent.pause() : this._(type: RoomPlaybackIntentType.pause);

  const RoomPlaybackIntent.resume()
    : this._(type: RoomPlaybackIntentType.resume);

  const RoomPlaybackIntent.skip() : this._(type: RoomPlaybackIntentType.skip);

  const RoomPlaybackIntent.closeRoom()
    : this._(type: RoomPlaybackIntentType.closeRoom);

  final RoomPlaybackIntentType type;
  final String? trackId;

  bool get isNone => type == RoomPlaybackIntentType.none;
}
