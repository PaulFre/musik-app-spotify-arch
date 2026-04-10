import 'package:flutter/material.dart';
import 'package:party_queue_app/src/app/services.dart';
import 'package:party_queue_app/src/features/party/application/party_room_controller.dart';
import 'package:party_queue_app/src/features/party/domain/join_input_parser.dart';
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
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _joinRoom() async {
    final parsedInput = parseJoinInput(_codeController.text);
    if (parsedInput == null) {
      setState(
        () => _error =
            'Bitte einen gueltigen Raumcode oder Einladungslink eingeben.',
      );
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
            ? 'Gast'
            : _nameController.text.trim(),
      ),
    );
    if (!mounted) {
      return;
    }
    if (!success) {
      setState(() => _error = controller.error ?? 'Beitritt fehlgeschlagen');
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
    return Scaffold(
      appBar: AppBar(title: const Text('Raum beitreten')),
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
            decoration: const InputDecoration(labelText: 'Anzeigename'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _codeController,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'Raumcode oder Link'),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _joinRoom, child: const Text('Beitreten')),
        ],
      ),
    );
  }
}
