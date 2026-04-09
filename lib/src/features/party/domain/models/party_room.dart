import 'package:party_queue_app/src/features/party/domain/models/queue_item.dart';
import 'package:party_queue_app/src/features/party/domain/models/room_playback_intent.dart';
import 'package:party_queue_app/src/features/party/domain/models/room_settings.dart';
import 'package:party_queue_app/src/features/party/domain/models/spotify_track.dart';
import 'package:party_queue_app/src/features/party/domain/models/user_profile.dart';

class PartyRoom {
  PartyRoom({
    required this.code,
    required this.hostUserId,
    required this.settings,
    required this.createdAt,
    Map<String, UserProfile>? participants,
    List<QueueItem>? queue,
    Map<String, DateTime>? cooldownByTrackId,
    this.desiredNowPlayingTrackId,
    this.playbackIntent = const RoomPlaybackIntent.none(),
    this.nowPlayingTrack,
    this.nowPlayingTrackId,
    this.isPaused = false,
    this.closedAt,
  }) : participants = participants ?? <String, UserProfile>{},
       queue = queue ?? <QueueItem>[],
       cooldownByTrackId = cooldownByTrackId ?? <String, DateTime>{};

  final String code;
  final String hostUserId;
  final RoomSettings settings;
  final DateTime createdAt;
  final Map<String, UserProfile> participants;
  final List<QueueItem> queue;
  final Map<String, DateTime> cooldownByTrackId;
  final String? desiredNowPlayingTrackId;
  final RoomPlaybackIntent playbackIntent;
  final SpotifyTrack? nowPlayingTrack;
  final String? nowPlayingTrackId;
  final bool isPaused;
  final DateTime? closedAt;

  bool get isClosed => closedAt != null;
  int get participantCount => participants.length;

  PartyRoom copyWith({
    String? code,
    String? hostUserId,
    RoomSettings? settings,
    DateTime? createdAt,
    Map<String, UserProfile>? participants,
    List<QueueItem>? queue,
    Map<String, DateTime>? cooldownByTrackId,
    String? desiredNowPlayingTrackId,
    RoomPlaybackIntent? playbackIntent,
    SpotifyTrack? nowPlayingTrack,
    String? nowPlayingTrackId,
    bool? isPaused,
    DateTime? closedAt,
  }) {
    return PartyRoom(
      code: code ?? this.code,
      hostUserId: hostUserId ?? this.hostUserId,
      settings: settings ?? this.settings,
      createdAt: createdAt ?? this.createdAt,
      participants:
          participants ?? Map<String, UserProfile>.from(this.participants),
      queue: queue ?? List<QueueItem>.from(this.queue),
      cooldownByTrackId:
          cooldownByTrackId ??
          Map<String, DateTime>.from(this.cooldownByTrackId),
      desiredNowPlayingTrackId:
          desiredNowPlayingTrackId ?? this.desiredNowPlayingTrackId,
      playbackIntent: playbackIntent ?? this.playbackIntent,
      nowPlayingTrack: nowPlayingTrack ?? this.nowPlayingTrack,
      nowPlayingTrackId: nowPlayingTrackId ?? this.nowPlayingTrackId,
      isPaused: isPaused ?? this.isPaused,
      closedAt: closedAt ?? this.closedAt,
    );
  }
}
