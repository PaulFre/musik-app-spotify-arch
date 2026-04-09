import 'dart:async';

import 'package:flutter/material.dart';
import 'package:party_queue_app/src/features/party/application/party_room_controller.dart';
import 'package:party_queue_app/src/features/party/domain/models/queue_item.dart';
import 'package:party_queue_app/src/features/party/domain/models/spotify_track.dart';
import 'package:party_queue_app/src/features/party/domain/models/vote_type.dart';

class RoomScreen extends StatefulWidget {
  const RoomScreen({super.key, required this.controller});

  final PartyRoomController controller;

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  String _query = '';
  bool _isSearching = false;
  String? _searchError;
  List<SpotifyTrack> _searchResults = const <SpotifyTrack>[];

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String rawQuery) async {
    final query = rawQuery.trim();
    if (query.isEmpty) {
      setState(() {
        _query = rawQuery;
        _isSearching = false;
        _searchError = null;
        _searchResults = const <SpotifyTrack>[];
      });
      return;
    }
    setState(() {
      _query = rawQuery;
      _isSearching = true;
      _searchError = null;
    });

    final tracks = await widget.controller.search(query);
    if (!mounted || _query.trim() != query) {
      return;
    }
    setState(() {
      _isSearching = false;
      _searchResults = tracks;
      _searchError = tracks.isEmpty
          ? 'Keine addbaren Spotify-Treffer gefunden.'
          : null;
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
  }

  @override
  Widget build(BuildContext context) {
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
            appBar: AppBar(title: const Text('Raum geschlossen')),
            body: const Center(
              child: Text('Der Host hat den Raum geschlossen.'),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text('Raum ${room.code}'),
            actions: [
              if (widget.controller.isHost)
                IconButton(
                  onPressed: () async => widget.controller.closeRoom(),
                  icon: const Icon(Icons.logout),
                  tooltip: 'Raum schliessen',
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
                title: widget.controller.nowPlayingTitle ?? 'Noch kein Song',
                paused: room.isPaused,
                playbackReady: widget.controller.isPlaybackReady,
                deviceLabel:
                    widget.controller.playbackState.selectedDeviceId ??
                    'Kein Geraet',
              ),
              const SizedBox(height: 12),
              _HostActions(controller: widget.controller),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Spotify Suche',
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
                                    _searchResults =
                                        const <SpotifyTrack>[];
                                  });
                                },
                              )),
                ),
                onChanged: _onSearchChanged,
              ),
              const SizedBox(height: 8),
              if (_query.trim().isEmpty)
                const Text(
                  'Tippe einen Song oder Artist ein. Addbar sind nur echte Spotify-Treffer.',
                )
              else if (_searchError != null)
                Text(
                  _searchError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                )
              else if (_searchResults.isNotEmpty)
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
              const SizedBox(height: 8),
              Text(
                'Teilnehmer: ${room.participantCount}/${room.settings.maxParticipants}',
              ),
              const SizedBox(height: 12),
              if (widget.controller.error != null)
                Card(
                  color: Colors.red.withValues(alpha: 0.12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(widget.controller.error!),
                  ),
                ),
              const SizedBox(height: 8),
              const Text(
                'Warteschlange',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (room.queue.isEmpty)
                const Text('Keine Songs verfuegbar.')
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
}

class _NowPlayingCard extends StatelessWidget {
  const _NowPlayingCard({
    required this.title,
    required this.paused,
    required this.playbackReady,
    required this.deviceLabel,
  });

  final String title;
  final bool paused;
  final bool playbackReady;
  final String deviceLabel;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: const Text('Now Playing'),
        subtitle: Text('$title\nDevice: $deviceLabel'),
        isThreeLine: true,
        trailing: Text(
          playbackReady ? (paused ? 'Pausiert' : 'Aktiv') : 'Setup offen',
        ),
      ),
    );
  }
}

class _HostActions extends StatelessWidget {
  const _HostActions({required this.controller});

  final PartyRoomController controller;

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
          const Chip(
            label: Text('Host braucht Spotify und ein Geraet fuer Playback'),
          ),
        FilledButton.tonal(
          onPressed: controller.isPlaybackReady ? controller.playTopSong : null,
          child: const Text('Top Song spielen'),
        ),
        FilledButton.tonal(
          onPressed: controller.isPlaybackReady
              ? controller.skipNowPlaying
              : null,
          child: const Text('Skip'),
        ),
        FilledButton.tonal(
          onPressed: controller.isPlaybackReady
              ? controller.pauseOrResume
              : null,
          child: const Text('Pause/Resume'),
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
