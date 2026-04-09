class RoomSettings {
  const RoomSettings({
    this.cooldownMinutes = 15,
    this.maxParticipants = 25,
    this.maxQueuedTracksPerUser = 3,
    this.isPublic = false,
    this.autoCloseMinutes = 120,
  });

  final int cooldownMinutes;
  final int maxParticipants;
  final int maxQueuedTracksPerUser;
  final bool isPublic;
  final int autoCloseMinutes;

  RoomSettings copyWith({
    int? cooldownMinutes,
    int? maxParticipants,
    int? maxQueuedTracksPerUser,
    bool? isPublic,
    int? autoCloseMinutes,
  }) {
    return RoomSettings(
      cooldownMinutes: cooldownMinutes ?? this.cooldownMinutes,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      maxQueuedTracksPerUser:
          maxQueuedTracksPerUser ?? this.maxQueuedTracksPerUser,
      isPublic: isPublic ?? this.isPublic,
      autoCloseMinutes: autoCloseMinutes ?? this.autoCloseMinutes,
    );
  }
}
