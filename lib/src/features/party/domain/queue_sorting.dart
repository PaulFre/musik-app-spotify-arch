import 'package:party_queue_app/src/features/party/domain/models/queue_item.dart';

List<QueueItem> sortedQueue(List<QueueItem> queue) {
  final copy = List<QueueItem>.from(queue);
  copy.sort((a, b) {
    final scoreCompare = b.score.compareTo(a.score);
    if (scoreCompare != 0) {
      return scoreCompare;
    }

    final likesCompare = b.likes.compareTo(a.likes);
    if (likesCompare != 0) {
      return likesCompare;
    }

    return a.addedAt.compareTo(b.addedAt);
  });
  return copy;
}
