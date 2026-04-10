import 'package:party_queue_app/src/features/party/domain/models/party_room.dart';

String buildRoomPlaylistExportText(PartyRoom room) {
  if (room.queue.isEmpty) {
    return '';
  }

  final buffer = StringBuffer()
    ..writeln('Party Queue Export')
    ..writeln('Raum ${room.code}')
    ..writeln();

  for (var index = 0; index < room.queue.length; index++) {
    final track = room.queue[index].track;
    buffer.write('${index + 1}. ${track.title} - ${track.artist}');
    if (track.uri != null && track.uri!.trim().isNotEmpty) {
      buffer.write(' (${track.uri})');
    }
    if (index < room.queue.length - 1) {
      buffer.writeln();
    }
  }

  return buffer.toString();
}
