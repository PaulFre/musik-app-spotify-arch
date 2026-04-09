import 'package:flutter/material.dart';
import 'package:party_queue_app/src/app/services.dart';
import 'package:party_queue_app/src/features/party/application/party_room_controller.dart';
import 'package:party_queue_app/src/features/party/domain/models/room_settings.dart';
import 'package:party_queue_app/src/features/party/domain/models/user_profile.dart';
import 'package:party_queue_app/src/features/party/presentation/room_screen.dart';
import 'package:party_queue_app/src/features/settings/presentation/settings_scope.dart';
import 'package:party_queue_app/src/features/spotify/application/spotify_connection_controller.dart';

class HostRoomScreen extends StatefulWidget {
  const HostRoomScreen({super.key});

  @override
  State<HostRoomScreen> createState() => _HostRoomScreenState();
}

class _HostRoomScreenState extends State<HostRoomScreen> {
  final _nameController = TextEditingController(text: 'Host');
  final SpotifyConnectionController _spotifyController =
      Services.spotifyConnectionController;
  int _cooldown = 15;
  int _maxParticipants = 25;
  bool _isPublic = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cooldown = SettingsScope.of(context).defaultCooldownMinutes;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _createRoom() async {
    final controller = PartyRoomController(
      repository: Services.partyRoomRepository,
      catalogService: Services.spotifyCatalogService,
      playbackOrchestrator: Services.playbackOrchestrator,
      spotifyConnectionController: _spotifyController,
    );
    final user = UserProfile(
      id: 'host-${DateTime.now().microsecondsSinceEpoch}',
      displayName: _nameController.text.trim().isEmpty
          ? 'Host'
          : _nameController.text.trim(),
      isHost: true,
    );

    await controller.createRoom(
      host: user,
      settings: RoomSettings(
        cooldownMinutes: _cooldown,
        maxParticipants: _maxParticipants,
        isPublic: _isPublic,
      ),
    );

    if (!mounted) {
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
      appBar: AppBar(title: const Text('Raum hosten')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AnimatedBuilder(
            animation: _spotifyController,
            builder: (context, _) {
              final connection = _spotifyController.connectionState;
              final playback = _spotifyController.playbackState;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Spotify-Host Setup',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        connection.spotifyConnected
                            ? 'Verbunden als ${connection.displayName ?? 'Spotify Host'}'
                            : 'Spotify noch nicht verbunden',
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.tonal(
                            onPressed: _spotifyController.isLoading
                                ? null
                                : _spotifyController.connectHost,
                            child: const Text('Mit Spotify verbinden'),
                          ),
                          OutlinedButton(
                            onPressed:
                                connection.spotifyConnected &&
                                    !_spotifyController.isLoading
                                ? _spotifyController.refreshDevices
                                : null,
                            child: const Text('Geraete laden'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (playback.availableDevices.isNotEmpty)
                        DropdownButtonFormField<String>(
                          initialValue: playback.selectedDeviceId,
                          items: playback.availableDevices
                              .map(
                                (device) => DropdownMenuItem<String>(
                                  value: device.id,
                                  child: Text(device.name),
                                ),
                              )
                              .toList(),
                          onChanged: connection.spotifyConnected
                              ? (value) {
                                  if (value != null) {
                                    _spotifyController.selectDevice(value);
                                  }
                                }
                              : null,
                          decoration: const InputDecoration(
                            labelText: 'Wiedergabegeraet',
                          ),
                        )
                      else
                        const Text(
                          'Noch keine Geraete geladen. Raum-Erstellung bleibt erlaubt, Playback aber gesperrt.',
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Dein Anzeigename'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _cooldown,
            items: const [0, 15, 30, 60]
                .map(
                  (minutes) => DropdownMenuItem(
                    value: minutes,
                    child: Text('$minutes Minuten Cooldown'),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _cooldown = value);
              }
            },
            decoration: const InputDecoration(labelText: 'Song-Cooldown'),
          ),
          const SizedBox(height: 12),
          Slider(
            value: _maxParticipants.toDouble(),
            min: 2,
            max: 100,
            divisions: 49,
            label: '$_maxParticipants',
            onChanged: (value) =>
                setState(() => _maxParticipants = value.toInt()),
          ),
          Text('Max. Teilnehmer: $_maxParticipants'),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('Oeffentlicher Raum'),
            value: _isPublic,
            onChanged: (value) => setState(() => _isPublic = value),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _createRoom,
            child: const Text('Raum erstellen'),
          ),
        ],
      ),
    );
  }
}
