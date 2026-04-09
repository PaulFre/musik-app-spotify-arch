class UserProfile {
  const UserProfile({
    required this.id,
    required this.displayName,
    this.isHost = false,
  });

  final String id;
  final String displayName;
  final bool isHost;

  UserProfile copyWith({String? id, String? displayName, bool? isHost}) {
    return UserProfile(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      isHost: isHost ?? this.isHost,
    );
  }
}
