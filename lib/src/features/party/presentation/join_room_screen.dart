import 'dart:async';

import 'package:flutter/material.dart';
import 'package:party_queue_app/src/app/app_strings.dart';
import 'package:party_queue_app/src/app/services.dart';
import 'package:party_queue_app/src/features/party/application/party_room_controller.dart';
import 'package:party_queue_app/src/features/party/domain/join_input_parser.dart';
import 'package:party_queue_app/src/features/party/domain/models/party_room.dart';
import 'package:party_queue_app/src/features/party/domain/models/user_profile.dart';
import 'package:party_queue_app/src/features/party/presentation/room_screen.dart';

class JoinRoomScreen extends StatefulWidget {
  const JoinRoomScreen({super.key, this.initialJoinInput});

  final String? initialJoinInput;

  @override
  State<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends State<JoinRoomScreen> {
  late final TextEditingController _codeController = TextEditingController(
    text: widget.initialJoinInput ?? '',
  );
  final _nameController = TextEditingController(text: 'Gast');
  final _passwordController = TextEditingController();
  String? _error;
  bool _nameEdited = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_nameEdited) {
      return;
    }
    final defaultName = context.strings.guestDefaultName;
    final currentText = _nameController.text.trim();
    if (currentText.isEmpty ||
        currentText == 'Gast' ||
        currentText == 'Guest') {
      _nameController.text = defaultName;
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _joinRoom() async {
    final strings = context.strings;
    final parsedInput = parseJoinInput(_codeController.text);
    if (parsedInput == null) {
      setState(() => _error = strings.invalidJoinInput);
      return;
    }
    final controller = PartyRoomController(
      repository: Services.partyRoomRepository,
      catalogService: Services.spotifyCatalogService,
      playbackOrchestrator: Services.playbackOrchestrator,
      spotifyConnectionController: Services.spotifyConnectionController,
    );
    final success = await controller.joinRoom(
      code: parsedInput.normalizedCode,
      user: UserProfile(
        id: 'guest-${DateTime.now().microsecondsSinceEpoch}',
        displayName: _nameController.text.trim().isEmpty
            ? strings.guestDefaultName
            : _nameController.text.trim(),
      ),
      password: _passwordController.text,
    );
    if (!mounted) {
      return;
    }
    if (!success) {
      setState(() {
        _error =
            _localizedJoinError(controller.error, strings) ??
            strings.joinFailed;
      });
      controller.dispose();
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RoomScreen(controller: controller),
      ),
    );
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return Scaffold(
      appBar: AppBar(title: Text(strings.joinRoom)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(labelText: strings.displayName),
            onChanged: (_) => _nameEdited = true,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _codeController,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(labelText: strings.roomCodeOrLink),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: InputDecoration(labelText: strings.privateRoomPassword),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _joinRoom, child: Text(strings.join)),
          const SizedBox(height: 24),
          Text(
            strings.publicRooms,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          StreamBuilder<List<PartyRoom>>(
            stream: Services.partyRoomRepository.watchPublicRooms(),
            builder: (context, snapshot) {
              final rooms = snapshot.data ?? const <PartyRoom>[];
              if (rooms.isEmpty) {
                return Text(strings.noPublicRoomsOpen);
              }
              return Column(
                children: rooms
                    .map(
                      (room) => Card(
                        child: ListTile(
                          title: Text(
                            room.participants[room.hostUserId]?.displayName ??
                                strings.hostLabel('Host'),
                          ),
                          subtitle: Text(
                            strings.publicRoomListSubtitle(
                              room.code,
                              room.participantCount,
                              room.settings.maxParticipants,
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            _codeController.text = room.code;
                            unawaited(_joinRoom());
                          },
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  String? _localizedJoinError(String? error, AppStrings strings) {
    switch (error) {
      case 'Room not found or closed.':
      case 'Raum nicht gefunden oder geschlossen.':
        return strings.roomNotFoundOrClosed();
      case 'Passwort fuer privaten Raum ist falsch.':
      case 'Private room password is incorrect.':
        return strings.privateRoomPasswordWrong();
      default:
        return error;
    }
  }
}
