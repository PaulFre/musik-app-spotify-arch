import 'dart:async';

import 'package:flutter/material.dart';
import 'package:party_queue_app/src/app/app_strings.dart';
import 'package:party_queue_app/src/app/services.dart';
import 'package:party_queue_app/src/features/party/application/party_room_controller.dart';
import 'package:party_queue_app/src/features/party/domain/room_invite_link_builder.dart';
import 'package:party_queue_app/src/features/party/domain/models/queue_item.dart';
import 'package:party_queue_app/src/features/party/domain/models/spotify_track.dart';
import 'package:party_queue_app/src/features/party/domain/models/vote_type.dart';
import 'package:party_queue_app/src/features/party/domain/room_playlist_export_builder.dart';
import 'package:party_queue_app/src/features/party/presentation/room_guests_sheet.dart';
import 'package:party_queue_app/src/features/party/presentation/room_invite_sheet.dart';
import 'package:party_queue_app/src/features/party/presentation/room_playlist_export_sheet.dart';
import 'package:party_queue_app/src/features/party/presentation/room_settings_sheet.dart';

class RoomScreen extends StatefulWidget {
  const RoomScreen({super.key, required this.controller});

  final PartyRoomController controller;

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  Timer? _playbackProgressTicker;
  String _query = '';
  bool _isSearching = false;
  String? _searchError;
  String? _searchNotice;
  List<SpotifyTrack> _searchResults = const <SpotifyTrack>[];
  List<SpotifyTrack> _suggestions = const <SpotifyTrack>[];
  bool _isLoadingSuggestions = false;
  String? _lastSuggestionContext;
  int _suggestionsRequestId = 0;
  String? _scheduledSuggestionContext;

  void _logSuggestions(String message) {
    debugPrint('[Suggestions][RoomScreen] $message');
  }

  void _scheduleSuggestionsReload(String suggestionContext) {
    if (_scheduledSuggestionContext == suggestionContext) {
      _logSuggestions(
        'schedule reload skipped already-scheduled context=$suggestionContext',
      );
      return;
    }
    _scheduledSuggestionContext = suggestionContext;
    _logSuggestions('schedule reload post-frame context=$suggestionContext');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (_scheduledSuggestionContext != suggestionContext) {
        _logSuggestions(
          'scheduled reload dropped stale context=$suggestionContext currentScheduled=$_scheduledSuggestionContext',
        );
        return;
      }
      _scheduledSuggestionContext = null;
      unawaited(_loadSuggestions());
    });
  }

  Future<void> _handleHostMenuAction(_HostMenuAction action) async {
    switch (action) {
      case _HostMenuAction.invite:
        await _showInviteSheet();
      case _HostMenuAction.exportPlaylist:
        await _showPlaylistExportSheet();
      case _HostMenuAction.guests:
        await _showGuestsSheet();
      case _HostMenuAction.settings:
        await _showSettingsSheet();
      case _HostMenuAction.closeRoom:
        await widget.controller.closeRoom();
    }
  }

  Future<void> _showInviteSheet() async {
    final room = widget.controller.room;
    if (room == null) {
      return;
    }
    final inviteLink = buildRoomInviteLink(
      room.code,
      publicBaseUri: Services.appConfig.publicInviteBaseUri,
    );
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) =>
          RoomInviteSheet(roomCode: room.code, inviteLink: inviteLink),
    );
  }

  Future<void> _showGuestsSheet() async {
    final room = widget.controller.room;
    if (room == null) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => RoomGuestsSheet(controller: widget.controller),
    );
  }

  Future<void> _showPlaylistExportSheet() async {
    final room = widget.controller.room;
    if (room == null || !widget.controller.isHost) {
      return;
    }
    final exportText = buildRoomPlaylistExportText(room);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => RoomPlaylistExportSheet(
        exportText: exportText,
        hasTracks: room.queue.isNotEmpty,
      ),
    );
  }

  Future<void> _showSettingsSheet() async {
    if (widget.controller.room == null || !widget.controller.isHost) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => RoomSettingsSheet(controller: widget.controller),
    );
  }

  @override
  void initState() {
    super.initState();
    _playbackProgressTicker = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) {
        if (!mounted) {
          return;
        }
        final playbackState = widget.controller.playbackState;
        if (playbackState.actualProgressMs == null ||
            playbackState.lastSyncedAt == null ||
            playbackState.actualIsPaused) {
          return;
        }
        setState(() {});
      },
    );
    unawaited(_loadSuggestions());
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _playbackProgressTicker?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  int? _displayProgressMs() {
    final playbackState = widget.controller.playbackState;
    final confirmedProgressMs = playbackState.actualProgressMs;
    if (confirmedProgressMs == null) {
      return null;
    }
    final syncTime = playbackState.lastSyncedAt;
    if (syncTime == null || playbackState.actualIsPaused) {
      return confirmedProgressMs;
    }
    final elapsedMs = DateTime.now().difference(syncTime).inMilliseconds;
    final nextProgressMs =
        confirmedProgressMs + (elapsedMs < 0 ? 0 : elapsedMs);
    final durationMs = playbackState.actualDurationMs;
    if (durationMs == null || durationMs <= 0) {
      return nextProgressMs;
    }
    return nextProgressMs.clamp(0, durationMs);
  }

  Future<void> _loadSuggestions() async {
    final requestId = ++_suggestionsRequestId;
    final room = widget.controller.room;
    final suggestionContext = room == null
        ? null
        : <String>[
            room.nowPlayingTrackId ?? '',
            ...room.queue.map((item) => item.track.id),
          ].join('|');
    _logSuggestions(
      '_loadSuggestions start requestId=$requestId context=$suggestionContext query="${_query.trim()}"',
    );
    if (mounted) {
      setState(() {
        _isLoadingSuggestions = true;
      });
      _logSuggestions(
        '_isLoadingSuggestions=true requestId=$requestId context=$suggestionContext',
      );
    }
    try {
      final suggestions = await widget.controller.loadSuggestions();
      _logSuggestions(
        '_loadSuggestions returned requestId=$requestId count=${suggestions.length} currentQuery="${_query.trim()}" currentRequestId=$_suggestionsRequestId',
      );
      if (!mounted || requestId != _suggestionsRequestId) {
        _logSuggestions(
          '_loadSuggestions stale-or-unmounted requestId=$requestId mounted=$mounted currentRequestId=$_suggestionsRequestId',
        );
        return;
      }
      if (_query.trim().isNotEmpty) {
        setState(() {
          _isLoadingSuggestions = false;
          _lastSuggestionContext = suggestionContext;
        });
        _logSuggestions(
          '_loadSuggestions aborted-by-query requestId=$requestId set loading=false lastContext=$suggestionContext',
        );
        return;
      }
      setState(() {
        _isLoadingSuggestions = false;
        _suggestions = suggestions.take(3).toList();
        _lastSuggestionContext = suggestionContext;
      });
      _logSuggestions(
        '_loadSuggestions success requestId=$requestId set loading=false lastContext=$suggestionContext visibleCount=${_suggestions.length}',
      );
    } catch (_) {
      if (!mounted || requestId != _suggestionsRequestId) {
        _logSuggestions(
          '_loadSuggestions catch-stale-or-unmounted requestId=$requestId mounted=$mounted currentRequestId=$_suggestionsRequestId',
        );
        return;
      }
      setState(() {
        _isLoadingSuggestions = false;
        _lastSuggestionContext = suggestionContext;
      });
      _logSuggestions(
        '_loadSuggestions catch requestId=$requestId set loading=false lastContext=$suggestionContext',
      );
    }
  }

  Future<void> _performSearch(String rawQuery) async {
    final strings = context.strings;
    final query = rawQuery.trim();
    if (query.isEmpty) {
      setState(() {
        _query = rawQuery;
        _isSearching = false;
        _searchError = null;
        _searchNotice = null;
        _searchResults = const <SpotifyTrack>[];
      });
      unawaited(_loadSuggestions());
      return;
    }
    setState(() {
      _query = rawQuery;
      _isSearching = true;
      _searchError = null;
      _searchNotice = null;
      _suggestions = const <SpotifyTrack>[];
    });

    final tracks = await widget.controller.search(query);
    final shouldWarnAboutExcludedArtist = widget.controller
        .isExplicitExcludedArtistQuery(query);
    if (!mounted || _query.trim() != query) {
      return;
    }
    setState(() {
      _isSearching = false;
      _searchResults = tracks;
      _searchNotice = shouldWarnAboutExcludedArtist
          ? strings.excludedArtistWarning
          : null;
      _searchError = tracks.isEmpty ? strings.noAddableResults : null;
    });
  }

  void _onSearchChanged(String value) {
    _query = value;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 300),
      () => _performSearch(value),
    );
  }

  Future<void> _addSearchResult(SpotifyTrack track) async {
    await widget.controller.addTrack(track);
    if (!mounted) {
      return;
    }
    setState(() {
      _searchController.clear();
      _query = '';
      _isSearching = false;
      _searchError = null;
      _searchResults = const <SpotifyTrack>[];
    });
    await _loadSuggestions();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final room = widget.controller.room;
        if (room == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (room.isClosed) {
          return Scaffold(
            appBar: AppBar(title: Text(strings.roomClosed)),
            body: Center(child: Text(strings.roomClosedMessage)),
          );
        }

        final currentSuggestionContext = <String>[
          room.nowPlayingTrackId ?? '',
          ...room.queue.map((item) => item.track.id),
        ].join('|');
        if (_query.trim().isEmpty &&
            !_isLoadingSuggestions &&
            _lastSuggestionContext != currentSuggestionContext) {
          _logSuggestions(
            'build-trigger reload currentContext=$currentSuggestionContext lastContext=$_lastSuggestionContext loading=$_isLoadingSuggestions query="${_query.trim()}"',
          );
          _scheduleSuggestionsReload(currentSuggestionContext);
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(strings.roomTitle(room.code)),
            actions: [
              if (widget.controller.isHost)
                PopupMenuButton<_HostMenuAction>(
                  tooltip: strings.hostMenu,
                  onSelected: (action) =>
                      unawaited(_handleHostMenuAction(action)),
                  itemBuilder: (context) => [
                    PopupMenuItem<_HostMenuAction>(
                      value: _HostMenuAction.invite,
                      child: Text(strings.invite),
                    ),
                    PopupMenuItem<_HostMenuAction>(
                      value: _HostMenuAction.exportPlaylist,
                      child: Text(strings.exportPlaylist),
                    ),
                    PopupMenuItem<_HostMenuAction>(
                      value: _HostMenuAction.guests,
                      child: Text(strings.guests),
                    ),
                    PopupMenuItem<_HostMenuAction>(
                      value: _HostMenuAction.settings,
                      child: Text(strings.settings),
                    ),
                    PopupMenuDivider(),
                    PopupMenuItem<_HostMenuAction>(
                      value: _HostMenuAction.closeRoom,
                      child: Text(strings.closeRoom),
                    ),
                  ],
                  icon: const Icon(Icons.menu),
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (room.playbackErrorMessage != null)
                Card(
                  color: Colors.orange.withValues(alpha: 0.12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(room.playbackErrorMessage!),
                  ),
                ),
              if (room.playbackErrorMessage != null) const SizedBox(height: 8),
              _NowPlayingCard(
                title: widget.controller.nowPlayingTitle ?? strings.noSongYet,
                artist: room.nowPlayingTrack?.artist,
                addedBy: widget.controller.nowPlayingAddedByDisplayName,
                progressMs: _displayProgressMs(),
                durationMs: widget.controller.playbackState.actualDurationMs,
                paused: room.isPaused,
                playbackReady: widget.controller.isPlaybackReady,
                strings: strings,
              ),
              const SizedBox(height: 12),
              _HostActions(controller: widget.controller, strings: strings),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: strings.spotifySearch,
                  suffixIcon: _isSearching
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : (_query.trim().isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  setState(() {
                                    _searchController.clear();
                                    _query = '';
                                    _searchError = null;
                                    _searchNotice = null;
                                    _searchResults = const <SpotifyTrack>[];
                                  });
                                },
                              )),
                ),
                onChanged: _onSearchChanged,
              ),
              const SizedBox(height: 8),
              if (_query.trim().isEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(strings.searchHint),
                    const SizedBox(height: 8),
                    Text(
                      strings.suggestions,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    if (_isLoadingSuggestions)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else if (_suggestions.isEmpty)
                      Text(strings.noSpotifySuggestions)
                    else
                      ..._suggestions.map(
                        (track) => Card(
                          child: ListTile(
                            title: Text(track.title),
                            subtitle: Text(track.artist),
                            trailing: IconButton(
                              icon: const Icon(Icons.add),
                              onPressed: () => _addSearchResult(track),
                            ),
                          ),
                        ),
                      ),
                  ],
                )
              else if (_searchError != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_searchNotice != null) ...[
                      Text(
                        _searchNotice!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Text(
                      _searchError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                )
              else if (_searchResults.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_searchNotice != null) ...[
                      Text(
                        _searchNotice!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    ..._searchResults.map(
                      (track) => Card(
                        child: ListTile(
                          title: Text(track.title),
                          subtitle: Text(track.artist),
                          trailing: IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: () => _addSearchResult(track),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 8),
              Text(
                strings.participantsSummary(
                  room.participantCount,
                  room.settings.maxParticipants,
                ),
              ),
              const SizedBox(height: 12),
              if (widget.controller.error != null)
                Card(
                  color: Colors.red.withValues(alpha: 0.12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      _localizedControllerError(
                            widget.controller.error,
                            strings,
                          ) ??
                          widget.controller.error!,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                strings.queue,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (room.queue.isEmpty)
                Text(strings.noSongsAvailable)
              else
                ...room.queue.map(
                  (item) =>
                      _QueueItemTile(controller: widget.controller, item: item),
                ),
            ],
          ),
        );
      },
    );
  }

  String? _localizedControllerError(String? error, AppStrings strings) {
    switch (error) {
      case 'Room not found or closed.':
      case 'Raum nicht gefunden oder geschlossen.':
        return strings.roomNotFoundOrClosed();
      case 'Dieser Interpret wurde vom Host ausgeschlossen.':
      case 'This artist has been excluded by the host.':
        return strings.excludedArtistAddError();
      default:
        return error;
    }
  }
}

enum _HostMenuAction { invite, exportPlaylist, guests, settings, closeRoom }

class _NowPlayingCard extends StatelessWidget {
  const _NowPlayingCard({
    required this.title,
    required this.artist,
    required this.addedBy,
    required this.progressMs,
    required this.durationMs,
    required this.paused,
    required this.playbackReady,
    required this.strings,
  });

  final String title;
  final String? artist;
  final String? addedBy;
  final int? progressMs;
  final int? durationMs;
  final bool paused;
  final bool playbackReady;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final safeDurationMs = durationMs != null && durationMs! > 0
        ? durationMs!
        : null;
    final safeProgressMs = progressMs != null && progressMs! >= 0
        ? progressMs!
        : null;
    final progressValue = safeDurationMs == null || safeProgressMs == null
        ? 0.0
        : (safeProgressMs / safeDurationMs).clamp(0.0, 1.0);
    return Card(
      child: ListTile(
        title: Text(strings.nowPlaying),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(artist ?? strings.unknownArtist),
            if (addedBy != null) Text(strings.addedBy(addedBy!)),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(_formatPlaybackTime(safeProgressMs)),
                const SizedBox(width: 8),
                Expanded(child: LinearProgressIndicator(value: progressValue)),
                const SizedBox(width: 8),
                Text(_formatPlaybackTime(safeDurationMs)),
              ],
            ),
          ],
        ),
        isThreeLine: true,
        trailing: Text(
          playbackReady
              ? (paused ? strings.paused : strings.active)
              : strings.setupOpen,
        ),
      ),
    );
  }

  String _formatPlaybackTime(int? milliseconds) {
    if (milliseconds == null) {
      return '--:--';
    }
    final totalSeconds = milliseconds ~/ 1000;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

class _HostActions extends StatelessWidget {
  const _HostActions({required this.controller, required this.strings});

  final PartyRoomController controller;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    if (!controller.isHost) {
      return const SizedBox.shrink();
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (!controller.isPlaybackReady)
          Chip(label: Text(strings.playbackHostNeedsSpotify)),
        FilledButton.tonal(
          onPressed: controller.isPlaybackReady ? controller.playTopSong : null,
          child: Text(strings.playTopSong),
        ),
        FilledButton.tonal(
          onPressed: controller.isPlaybackReady
              ? controller.skipNowPlaying
              : null,
          child: Text(strings.skip),
        ),
        FilledButton.tonal(
          onPressed: controller.isPlaybackReady
              ? controller.pauseOrResume
              : null,
          child: Text(strings.pauseResume),
        ),
      ],
    );
  }
}

class _QueueItemTile extends StatelessWidget {
  const _QueueItemTile({required this.controller, required this.item});

  final PartyRoomController controller;
  final QueueItem item;

  @override
  Widget build(BuildContext context) {
    final myUserId = controller.activeUserId;
    final myVote = myUserId == null ? VoteType.none : item.voteOf(myUserId);
    return Card(
      child: ListTile(
        title: Text(item.track.title),
        subtitle: Text('${item.track.artist} | Score: ${item.score}'),
        trailing: Wrap(
          spacing: 4,
          children: [
            IconButton(
              onPressed: () => controller.vote(
                trackId: item.track.id,
                voteType: VoteType.like,
              ),
              icon: Icon(
                Icons.thumb_up,
                color: myVote == VoteType.like ? Colors.green : null,
              ),
            ),
            IconButton(
              onPressed: () => controller.vote(
                trackId: item.track.id,
                voteType: VoteType.dislike,
              ),
              icon: Icon(
                Icons.thumb_down,
                color: myVote == VoteType.dislike ? Colors.red : null,
              ),
            ),
            if (controller.isHost)
              IconButton(
                onPressed: () => controller.removeSong(item.track.id),
                icon: const Icon(Icons.delete_outline),
              ),
          ],
        ),
      ),
    );
  }
}
