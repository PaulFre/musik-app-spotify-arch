import 'package:party_queue_app/src/features/party/domain/models/queue_item.dart';
import 'package:party_queue_app/src/features/party/domain/models/room_playback_intent.dart';
import 'package:party_queue_app/src/features/party/domain/models/room_settings.dart';
import 'package:party_queue_app/src/features/party/domain/models/spotify_track.dart';
import 'package:party_queue_app/src/features/party/domain/models/user_profile.dart';

const Object _unset = Object();

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
    this.playbackIntentVersion = 0,
    this.nowPlayingTrack,
    this.nowPlayingTrackId,
    this.isPaused = false,
    this.playbackErrorMessage,
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
  final int playbackIntentVersion;
  final SpotifyTrack? nowPlayingTrack;
  final String? nowPlayingTrackId;
  final bool isPaused;
  final String? playbackErrorMessage;
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
    Object? desiredNowPlayingTrackId = _unset,
    RoomPlaybackIntent? playbackIntent,
    int? playbackIntentVersion,
    Object? nowPlayingTrack = _unset,
    Object? nowPlayingTrackId = _unset,
    bool? isPaused,
    Object? playbackErrorMessage = _unset,
    Object? closedAt = _unset,
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
          desiredNowPlayingTrackId == _unset
          ? this.desiredNowPlayingTrackId
          : desiredNowPlayingTrackId as String?,
      playbackIntent: playbackIntent ?? this.playbackIntent,
      playbackIntentVersion:
          playbackIntentVersion ?? this.playbackIntentVersion,
      nowPlayingTrack: nowPlayingTrack == _unset
          ? this.nowPlayingTrack
          : nowPlayingTrack as SpotifyTrack?,
      nowPlayingTrackId: nowPlayingTrackId == _unset
          ? this.nowPlayingTrackId
          : nowPlayingTrackId as String?,
      isPaused: isPaused ?? this.isPaused,
      playbackErrorMessage: playbackErrorMessage == _unset
          ? this.playbackErrorMessage
          : playbackErrorMessage as String?,
      closedAt: closedAt == _unset ? this.closedAt : closedAt as DateTime?,
    );
  }
}
