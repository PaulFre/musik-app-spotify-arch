import 'dart:async';

import 'package:flutter/material.dart';
import 'package:party_queue_app/src/app/services.dart';
import 'package:party_queue_app/src/features/party/data/host_flow_resume_store.dart';
import 'package:party_queue_app/src/features/party/presentation/host_room_screen.dart';
import 'package:party_queue_app/src/features/party/presentation/join_room_screen.dart';
import 'package:party_queue_app/src/features/settings/presentation/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _pendingHostResumeChecked = false;
  bool _pendingHostResume = false;
  bool _hostFlowRestored = false;

  @override
  void initState() {
    super.initState();
    Services.spotifyConnectionController.addListener(_handleConnectionChanged);
    unawaited(_loadPendingHostResume());
  }

  @override
  void dispose() {
    Services.spotifyConnectionController.removeListener(_handleConnectionChanged);
    super.dispose();
  }

  Future<void> _loadPendingHostResume() async {
    final pending = await HostFlowResumeStore.consumePendingHostSetup();
    if (!mounted) {
      return;
    }
    _pendingHostResumeChecked = true;
    _pendingHostResume = pending;
    _maybeRestoreHostFlow();
  }

  void _handleConnectionChanged() {
    _maybeRestoreHostFlow();
  }

  void _maybeRestoreHostFlow() {
    if (!_pendingHostResumeChecked || !_pendingHostResume || _hostFlowRestored) {
      return;
    }
    final spotifyController = Services.spotifyConnectionController;
    if (spotifyController.isLoading) {
      return;
    }
    _hostFlowRestored = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const HostRoomScreen(),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Party Queue')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Demokratische Spotify-Queue',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const HostRoomScreen()),
                    );
                  },
                  child: const Text('Raum hosten'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const JoinRoomScreen()),
                    );
                  },
                  child: const Text('Raum beitreten'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
                    );
                  },
                  child: const Text('Einstellungen'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
