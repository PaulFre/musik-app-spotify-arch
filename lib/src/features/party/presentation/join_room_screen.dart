import 'package:flutter/material.dart';
import 'package:party_queue_app/src/app/services.dart';
import 'package:party_queue_app/src/features/party/application/party_room_controller.dart';
import 'package:party_queue_app/src/features/party/domain/models/user_profile.dart';
import 'package:party_queue_app/src/features/party/presentation/room_screen.dart';

class JoinRoomScreen extends StatefulWidget {
  const JoinRoomScreen({super.key});

  @override
  State<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends State<JoinRoomScreen> {
  final _codeController = TextEditingController();
  final _nameController = TextEditingController(text: 'Gast');
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _joinRoom() async {
    final controller = PartyRoomController(
      repository: Services.partyRoomRepository,
      catalogService: Services.spotifyCatalogService,
      playbackOrchestrator: Services.playbackOrchestrator,
      spotifyConnectionController: Services.spotifyConnectionController,
    );
    final success = await controller.joinRoom(
      code: _codeController.text.trim().toUpperCase(),
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
            decoration: const InputDecoration(labelText: 'Raumcode'),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _joinRoom, child: const Text('Beitreten')),
        ],
      ),
    );
  }
}
