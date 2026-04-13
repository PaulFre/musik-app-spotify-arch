import 'package:flutter/material.dart';
import 'package:party_queue_app/src/features/party/application/party_room_controller.dart';
import 'package:party_queue_app/src/features/party/domain/models/spotify_artist_ref.dart';
import 'package:party_queue_app/src/features/party/domain/models/spotify_track.dart';

class RoomSettingsSheet extends StatefulWidget {
  const RoomSettingsSheet({super.key, required this.controller});

  final PartyRoomController controller;

  @override
  State<RoomSettingsSheet> createState() => _RoomSettingsSheetState();
}

class _RoomSettingsSheetState extends State<RoomSettingsSheet> {
  late int _cooldownMinutes;
  late int _maxParticipants;
  late int _maxQueuedTracksPerUser;
  late List<SpotifyTrack> _excludedTracks;
  late List<SpotifyArtistRef> _excludedArtists;
  final TextEditingController _excludeSearchController =
      TextEditingController();
  final TextEditingController _excludeArtistController = TextEditingController();
  List<SpotifyTrack> _excludeSearchResults = const <SpotifyTrack>[];
  List<SpotifyArtistRef> _excludeArtistResults = const <SpotifyArtistRef>[];
  bool _isSearchingTracks = false;
  bool _isSearchingArtists = false;
  String? _validationMessage;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final settings = widget.controller.room!.settings;
    _cooldownMinutes = settings.cooldownMinutes;
    _maxParticipants = settings.maxParticipants;
    _maxQueuedTracksPerUser = settings.maxQueuedTracksPerUser;
    _excludedTracks = List<SpotifyTrack>.from(settings.excludedTracks);
    _excludedArtists = List<SpotifyArtistRef>.from(settings.excludedArtists);
  }

  @override
  void dispose() {
    _excludeSearchController.dispose();
    _excludeArtistController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.controller.room;
    if (room == null) {
      return const SizedBox.shrink();
    }
    final minParticipants = room.participantCount.clamp(1, 100);
    final participantDivisions = minParticipants < 100
        ? 100 - minParticipants
        : null;
    final canEdit = widget.controller.isHost && !_isSaving;

    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.9,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Raum-Einstellungen',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('Diese Limits gelten direkt fuer den aktuellen Raum.'),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<int>(
                        initialValue: _cooldownMinutes,
                        items: const [0, 5, 15, 30, 60]
                            .map(
                              (minutes) => DropdownMenuItem<int>(
                                value: minutes,
                                child: Text('$minutes Minuten Cooldown'),
                              ),
                            )
                            .toList(),
                        onChanged: canEdit
                            ? (value) {
                                if (value != null) {
                                  setState(() => _cooldownMinutes = value);
                                }
                              }
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Song-Cooldown',
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text('Max. Teilnehmer: $_maxParticipants'),
                      Slider(
                        value: _maxParticipants.toDouble(),
                        min: minParticipants.toDouble(),
                        max: 100,
                        divisions: participantDivisions,
                        label: '$_maxParticipants',
                        onChanged: canEdit
                            ? (value) {
                                setState(
                                  () => _maxParticipants = value.toInt(),
                                );
                              }
                            : null,
                      ),
                      const SizedBox(height: 8),
                      Text('Queue-Limit pro Nutzer: $_maxQueuedTracksPerUser'),
                      Slider(
                        value: _maxQueuedTracksPerUser.toDouble(),
                        min: 1,
                        max: 10,
                        divisions: 9,
                        label: '$_maxQueuedTracksPerUser',
                        onChanged: canEdit
                            ? (value) {
                                setState(
                                  () => _maxQueuedTracksPerUser = value.toInt(),
                                );
                              }
                            : null,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Ausgeschlossene Songs',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _excludeSearchController,
                              enabled: canEdit,
                              decoration: const InputDecoration(
                                labelText: 'Song fuer Ausschluss suchen',
                              ),
                              onSubmitted: canEdit
                                  ? (_) => _searchExcludedTrackCandidates()
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.tonal(
                            onPressed: canEdit && !_isSearchingTracks
                                ? _searchExcludedTrackCandidates
                                : null,
                            child: Text(
                              _isSearchingTracks ? 'Sucht...' : 'Suchen',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_excludeSearchResults.isNotEmpty)
                        ..._excludeSearchResults.map(
                          (track) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(track.title),
                            subtitle: Text(track.artist),
                            trailing: IconButton(
                              onPressed: canEdit
                                  ? () => _addExcludedTrack(track)
                                  : null,
                              icon: const Icon(Icons.block),
                              tooltip: 'Song ausschliessen',
                            ),
                          ),
                        ),
                      if (_excludedTracks.isEmpty)
                        const Text('Aktuell sind keine Songs ausgeschlossen.')
                      else
                        ..._excludedTracks.map(
                          (track) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(track.title),
                            subtitle: Text(track.artist),
                            trailing: IconButton(
                              onPressed: canEdit
                                  ? () => _removeExcludedTrack(track.id)
                                  : null,
                              icon: const Icon(Icons.delete_outline),
                              tooltip: 'Ausschluss entfernen',
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      const Text(
                        'Ausgeschlossene Interpreten',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _excludeArtistController,
                              enabled: canEdit,
                              decoration: const InputDecoration(
                                labelText: 'Interpret fuer Ausschluss suchen',
                              ),
                              onSubmitted: canEdit
                                  ? (_) => _searchExcludedArtistCandidates()
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.tonal(
                            onPressed: canEdit && !_isSearchingArtists
                                ? _searchExcludedArtistCandidates
                                : null,
                            child: Text(
                              _isSearchingArtists ? 'Sucht...' : 'Suchen',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_excludeArtistResults.isNotEmpty)
                        ..._excludeArtistResults.map(
                          (artist) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(artist.name),
                            trailing: IconButton(
                              onPressed: canEdit
                                  ? () => _addExcludedArtist(artist)
                                  : null,
                              icon: const Icon(Icons.person_off_outlined),
                              tooltip: 'Interpret ausschliessen',
                            ),
                          ),
                        ),
                      if (_excludedArtists.isEmpty)
                        const Text('Aktuell sind keine Interpreten ausgeschlossen.')
                      else
                        ..._excludedArtists.map(
                          (artist) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(artist.name),
                            trailing: IconButton(
                              onPressed: canEdit
                                  ? () => _removeExcludedArtist(artist.id)
                                  : null,
                              icon: const Icon(Icons.delete_outline),
                              tooltip: 'Ausschluss entfernen',
                            ),
                          ),
                        ),
                      if (_validationMessage != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _validationMessage!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: canEdit ? _save : null,
                  child: Text(_isSaving ? 'Speichert...' : 'Speichern'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final room = widget.controller.room;
    if (room == null) {
      return;
    }
    if (_maxParticipants < room.participantCount) {
      setState(() {
        _validationMessage =
            'Teilnehmerlimit darf nicht unter den aktuellen Teilnehmern liegen.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _validationMessage = null;
    });

    final success = await widget.controller.updateRoomSettings(
      room.settings.copyWith(
        cooldownMinutes: _cooldownMinutes,
        maxParticipants: _maxParticipants,
        maxQueuedTracksPerUser: _maxQueuedTracksPerUser,
        excludedTracks: _excludedTracks,
        excludedArtists: _excludedArtists,
      ),
    );

    if (!mounted) {
      return;
    }

    if (!success) {
      setState(() {
        _isSaving = false;
        _validationMessage =
            widget.controller.error ??
            'Raum-Einstellungen konnten nicht gespeichert werden.';
      });
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Raum-Einstellungen gespeichert.')),
      );
  }

  Future<void> _searchExcludedTrackCandidates() async {
    final query = _excludeSearchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _excludeSearchResults = const <SpotifyTrack>[];
      });
      return;
    }
    setState(() {
      _isSearchingTracks = true;
    });
    final results = await widget.controller.search(query);
    if (!mounted) {
      return;
    }
    final excludedIds = _excludedTracks.map((track) => track.id).toSet();
    setState(() {
      _isSearchingTracks = false;
      _excludeSearchResults = results
          .where((track) => !excludedIds.contains(track.id))
          .take(5)
          .toList();
    });
  }

  void _addExcludedTrack(SpotifyTrack track) {
    if (_excludedTracks.any((item) => item.id == track.id)) {
      return;
    }
    setState(() {
      _excludedTracks = List<SpotifyTrack>.from(_excludedTracks)..add(track);
      _excludeSearchResults = _excludeSearchResults
          .where((item) => item.id != track.id)
          .toList();
    });
  }

  void _removeExcludedTrack(String trackId) {
    setState(() {
      _excludedTracks = _excludedTracks
          .where((track) => track.id != trackId)
          .toList();
    });
  }

  Future<void> _searchExcludedArtistCandidates() async {
    final query = _excludeArtistController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _excludeArtistResults = const <SpotifyArtistRef>[];
      });
      return;
    }
    setState(() {
      _isSearchingArtists = true;
    });
    final results = await widget.controller.search(query);
    if (!mounted) {
      return;
    }
    final excludedIds = _excludedArtists.map((artist) => artist.id).toSet();
    final candidates = <SpotifyArtistRef>[];
    final seenIds = <String>{};
    for (final track in results) {
      for (final artist in track.artistRefs) {
        if (excludedIds.contains(artist.id) || !seenIds.add(artist.id)) {
          continue;
        }
        candidates.add(artist);
        if (candidates.length == 5) {
          break;
        }
      }
      if (candidates.length == 5) {
        break;
      }
    }
    setState(() {
      _isSearchingArtists = false;
      _excludeArtistResults = candidates;
    });
  }

  void _addExcludedArtist(SpotifyArtistRef artist) {
    if (_excludedArtists.any((item) => item.id == artist.id)) {
      return;
    }
    setState(() {
      _excludedArtists = List<SpotifyArtistRef>.from(_excludedArtists)..add(artist);
      _excludeArtistResults = _excludeArtistResults
          .where((item) => item.id != artist.id)
          .toList();
    });
  }

  void _removeExcludedArtist(String artistId) {
    setState(() {
      _excludedArtists = _excludedArtists
          .where((artist) => artist.id != artistId)
          .toList();
    });
  }
}
