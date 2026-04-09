import 'dart:math';

String generateRoomCode({int length = 6}) {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final random = Random();
  return List.generate(
    length,
    (_) => chars[random.nextInt(chars.length)],
  ).join();
}
