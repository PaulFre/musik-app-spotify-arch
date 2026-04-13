import 'package:flutter/material.dart';
import 'package:party_queue_app/src/app/app_strings.dart';
import 'package:party_queue_app/src/app/services.dart';
import 'package:party_queue_app/src/features/party/application/party_room_controller.dart';
import 'package:party_queue_app/src/features/party/data/host_flow_resume_store.dart';
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
  final _passwordController = TextEditingController();
  final SpotifyConnectionController _spotifyController =
      Services.spotifyConnectionController;
  late PartyRoomController _setupController;
  int _cooldown = 15;
  int _maxParticipants = 25;
  bool _isPublic = false;
  String? _lastSnackErrorCode;
  String? _roomConfigError;

  @override
  void initState() {
    super.initState();
    _setupController = _createSetupController();
    _spotifyController.addListener(_handleSpotifyStateChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cooldown = SettingsScope.of(context).defaultCooldownMinutes;
  }

  @override
  void dispose() {
    _spotifyController.removeListener(_handleSpotifyStateChanged);
    _setupController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  PartyRoomController _createSetupController() {
    return PartyRoomController(
      repository: Services.partyRoomRepository,
      catalogService: Services.spotifyCatalogService,
      playbackOrchestrator: Services.playbackOrchestrator,
      spotifyConnectionController: _spotifyController,
    );
  }

  void _handleSpotifyStateChanged() {
    final connection = _spotifyController.connectionState;
    final errorCode = connection.errorCode;
    if (!mounted ||
        errorCode == null ||
        errorCode == _lastSnackErrorCode ||
        errorCode != 'spotify-auth-cancelled') {
      return;
    }
    _lastSnackErrorCode = errorCode;
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          connection.errorMessage ?? context.strings.spotifyConnectionCancelled,
        ),
      ),
    );
  }

  Future<void> _connectSpotify() async {
    await HostFlowResumeStore.markPendingHostSetup();
    await _spotifyController.connectHost();
  }

  Future<void> _createRoom() async {
    final strings = context.strings;
    final trimmedPassword = _passwordController.text.trim();
    if (!_isPublic && trimmedPassword.isEmpty) {
      setState(() {
        _roomConfigError = strings.missingPrivateRoomPassword;
      });
      return;
    }
    if (_roomConfigError != null && mounted) {
      setState(() {
        _roomConfigError = null;
      });
    }
    final settings = RoomSettings(
      cooldownMinutes: _cooldown,
      maxParticipants: _maxParticipants,
      isPublic: _isPublic,
      roomPassword: _isPublic ? null : trimmedPassword,
    );

    final user = UserProfile(
      id: 'host-${DateTime.now().microsecondsSinceEpoch}',
      displayName: _nameController.text.trim().isEmpty
          ? 'Host'
          : _nameController.text.trim(),
      isHost: true,
    );

    await _setupController.createRoom(host: user, settings: settings);

    if (!mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RoomScreen(controller: _setupController),
      ),
    );
    _setupController.dispose();
    _setupController = _createSetupController();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return Scaffold(
      appBar: AppBar(title: Text(strings.hostRoom)),
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
                      Text(
                        strings.spotifyHostSetup,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        connection.spotifyConnected
                            ? strings.connectedAs(
                                connection.displayName ??
                                    strings.spotifyHostFallback,
                              )
                            : strings.spotifyNotConnected,
                      ),
                      if (connection.errorMessage != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          connection.errorMessage!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.tonal(
                            onPressed:
                                _spotifyController.isLoading ||
                                    connection.spotifyConnected
                                ? null
                                : _connectSpotify,
                            child: Text(
                              connection.spotifyConnected
                                  ? strings.spotifyConnected
                                  : strings.connectSpotify,
                            ),
                          ),
                          OutlinedButton(
                            onPressed:
                                connection.spotifyConnected &&
                                    !_spotifyController.isLoading
                                ? _spotifyController.refreshDevices
                                : null,
                            child: Text(strings.loadDevices),
                          ),
                          OutlinedButton(
                            onPressed:
                                connection.spotifyConnected &&
                                    !_spotifyController.isLoading
                                ? _spotifyController.disconnect
                                : null,
                            child: Text(strings.logout),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_roomConfigError != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _roomConfigError!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      if (playback.playbackError != null) ...[
                        Text(
                          playback.playbackError!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
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
                          decoration: InputDecoration(
                            labelText: strings.playbackDevice,
                          ),
                        )
                      else
                        Text(
                          playback.playbackError ??
                              strings.playbackSetupStillOpen,
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
            decoration: InputDecoration(labelText: strings.yourDisplayName),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _cooldown,
            items: [0, 15, 30, 60]
                .map(
                  (minutes) => DropdownMenuItem(
                    value: minutes,
                    child: Text(strings.cooldownOption(minutes)),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _cooldown = value);
              }
            },
            decoration: InputDecoration(labelText: strings.songCooldown),
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
          Text(strings.maxParticipants(_maxParticipants)),
          const SizedBox(height: 8),
          SwitchListTile(
            title: Text(strings.publicRoom),
            value: _isPublic,
            onChanged: (value) {
              setState(() {
                _isPublic = value;
                _roomConfigError = null;
                if (_isPublic) {
                  _passwordController.clear();
                }
              });
            },
          ),
          if (!_isPublic) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: strings.privateRoomPassword,
              ),
              onChanged: (_) {
                if (_roomConfigError == null) {
                  return;
                }
                setState(() {
                  _roomConfigError = null;
                });
              },
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(onPressed: _createRoom, child: Text(strings.createRoom)),
        ],
      ),
    );
  }
}
