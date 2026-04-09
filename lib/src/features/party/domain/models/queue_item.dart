import 'package:party_queue_app/src/features/party/domain/models/spotify_track.dart';
import 'package:party_queue_app/src/features/party/domain/models/vote_type.dart';

class QueueItem {
  QueueItem({
    required this.track,
    required this.addedByUserId,
    required this.addedAt,
    Map<String, VoteType>? votes,
  }) : votes = votes ?? <String, VoteType>{};

  final SpotifyTrack track;
  final String addedByUserId;
  final DateTime addedAt;
  final Map<String, VoteType> votes;

  int get likes => votes.values.where((vote) => vote == VoteType.like).length;
  int get dislikes =>
      votes.values.where((vote) => vote == VoteType.dislike).length;
  int get score => likes - dislikes;

  bool hasUserVoted(String userId) {
    return votes[userId] != null && votes[userId] != VoteType.none;
  }

  VoteType voteOf(String userId) => votes[userId] ?? VoteType.none;

  QueueItem copyWith({
    SpotifyTrack? track,
    String? addedByUserId,
    DateTime? addedAt,
    Map<String, VoteType>? votes,
  }) {
    return QueueItem(
      track: track ?? this.track,
      addedByUserId: addedByUserId ?? this.addedByUserId,
      addedAt: addedAt ?? this.addedAt,
      votes: votes ?? Map<String, VoteType>.from(this.votes),
    );
  }
}
