import 'package:flutter/material.dart';
import 'package:party_queue_app/src/features/party/application/party_room_controller.dart';

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
  String? _validationMessage;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final settings = widget.controller.room!.settings;
    _cooldownMinutes = settings.cooldownMinutes;
    _maxParticipants = settings.maxParticipants;
    _maxQueuedTracksPerUser = settings.maxQueuedTracksPerUser;
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
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Raum-Einstellungen',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Diese Limits gelten direkt fuer den aktuellen Raum.'),
            const SizedBox(height: 16),
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
              decoration: const InputDecoration(labelText: 'Song-Cooldown'),
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
                      setState(() => _maxParticipants = value.toInt());
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
                      setState(() => _maxQueuedTracksPerUser = value.toInt());
                    }
                  : null,
            ),
            if (_validationMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _validationMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
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
}
