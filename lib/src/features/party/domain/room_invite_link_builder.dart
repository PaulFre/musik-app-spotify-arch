Uri buildRoomInviteLink(String roomCode, {required Uri publicBaseUri}) {
  final normalizedCode = roomCode.trim().toUpperCase();
  return publicBaseUri.replace(
    path: '/join',
    queryParameters: <String, String>{'code': normalizedCode},
    fragment: null,
  );
}
