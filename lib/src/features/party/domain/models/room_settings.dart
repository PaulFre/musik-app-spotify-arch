class RoomSettings {
  const RoomSettings({
    this.cooldownMinutes = 15,
    this.maxParticipants = 25,
    this.isPublic = false,
    this.autoCloseMinutes = 120,
  });

  final int cooldownMinutes;
  final int maxParticipants;
  final bool isPublic;
  final int autoCloseMinutes;

  RoomSettings copyWith({
    int? cooldownMinutes,
    int? maxParticipants,
    bool? isPublic,
    int? autoCloseMinutes,
  }) {
    return RoomSettings(
      cooldownMinutes: cooldownMinutes ?? this.cooldownMinutes,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      isPublic: isPublic ?? this.isPublic,
      autoCloseMinutes: autoCloseMinutes ?? this.autoCloseMinutes,
    );
  }
}
