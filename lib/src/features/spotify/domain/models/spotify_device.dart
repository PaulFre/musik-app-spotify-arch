class SpotifyDevice {
  const SpotifyDevice({
    required this.id,
    required this.name,
    required this.type,
    this.isActive = false,
  });

  final String id;
  final String name;
  final String type;
  final bool isActive;

  SpotifyDevice copyWith({
    String? id,
    String? name,
    String? type,
    bool? isActive,
  }) {
    return SpotifyDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      isActive: isActive ?? this.isActive,
    );
  }
}
