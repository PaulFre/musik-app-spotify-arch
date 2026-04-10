import 'package:flutter_test/flutter_test.dart';
import 'package:party_queue_app/src/features/party/domain/models/party_room.dart';
import 'package:party_queue_app/src/features/party/domain/models/queue_item.dart';
import 'package:party_queue_app/src/features/party/domain/models/room_settings.dart';
import 'package:party_queue_app/src/features/party/domain/models/spotify_track.dart';
import 'package:party_queue_app/src/features/party/domain/room_playlist_export_builder.dart';

void main() {
  test('builds playlist export text in queue order', () {
    final room = PartyRoom(
      code: 'AB12CD',
      hostUserId: 'host-1',
      settings: const RoomSettings(),
      createdAt: DateTime(2026),
      queue: <QueueItem>[
        QueueItem(
          track: const SpotifyTrack(
            id: '1',
            uri: 'spotify:track:1',
            title: 'First Song',
            artist: 'Artist A',
          ),
          addedByUserId: 'guest-1',
          addedAt: DateTime(2026),
        ),
        QueueItem(
          track: const SpotifyTrack(
            id: '2',
            uri: 'spotify:track:2',
            title: 'Second Song',
            artist: 'Artist B',
          ),
          addedByUserId: 'guest-2',
          addedAt: DateTime(2026),
        ),
      ],
    );

    final export = buildRoomPlaylistExportText(room);

    expect(export, contains('Party Queue Export'));
    expect(export, contains('Raum AB12CD'));
    expect(export, contains('1. First Song - Artist A (spotify:track:1)'));
    expect(export, contains('2. Second Song - Artist B (spotify:track:2)'));
    expect(
      export.indexOf('1. First Song - Artist A'),
      lessThan(export.indexOf('2. Second Song - Artist B')),
    );
  });

  test('returns empty export for an empty queue', () {
    final room = PartyRoom(
      code: 'AB12CD',
      hostUserId: 'host-1',
      settings: const RoomSettings(),
      createdAt: DateTime(2026),
    );

    expect(buildRoomPlaylistExportText(room), isEmpty);
  });
}
