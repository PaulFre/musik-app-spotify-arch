import 'package:flutter_test/flutter_test.dart';
import 'package:party_queue_app/src/features/party/domain/models/queue_item.dart';
import 'package:party_queue_app/src/features/party/domain/models/spotify_track.dart';
import 'package:party_queue_app/src/features/party/domain/models/vote_type.dart';
import 'package:party_queue_app/src/features/party/domain/queue_sorting.dart';

void main() {
  test('sorts by score, then likes, then addedAt', () {
    final now = DateTime(2026, 2, 18, 12);
    final a = QueueItem(
      track: const SpotifyTrack(id: 'a', title: 'A', artist: 'X'),
      addedByUserId: 'u1',
      addedAt: now,
      votes: <String, VoteType>{'u1': VoteType.like},
    );
    final b = QueueItem(
      track: const SpotifyTrack(id: 'b', title: 'B', artist: 'X'),
      addedByUserId: 'u2',
      addedAt: now.add(const Duration(minutes: 1)),
      votes: <String, VoteType>{
        'u1': VoteType.like,
        'u2': VoteType.like,
        'u3': VoteType.dislike,
      },
    );
    final c = QueueItem(
      track: const SpotifyTrack(id: 'c', title: 'C', artist: 'X'),
      addedByUserId: 'u3',
      addedAt: now.add(const Duration(minutes: 2)),
      votes: <String, VoteType>{'u2': VoteType.like},
    );
    final sorted = sortedQueue(<QueueItem>[c, a, b]);
    expect(sorted.map((e) => e.track.id).toList(), <String>['b', 'a', 'c']);
  });
}
