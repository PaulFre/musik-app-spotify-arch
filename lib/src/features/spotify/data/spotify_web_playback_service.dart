import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:party_queue_app/src/features/party/domain/models/spotify_track.dart';
import 'package:party_queue_app/src/features/spotify/data/spotify_app_config.dart';
import 'package:party_queue_app/src/features/spotify/domain/models/playback_command_result.dart';
import 'package:party_queue_app/src/features/spotify/domain/models/spotify_device.dart';
import 'package:party_queue_app/src/features/spotify/domain/models/spotify_playback_state.dart';
import 'package:party_queue_app/src/features/spotify/domain/spotify_auth_service.dart';
import 'package:party_queue_app/src/features/spotify/domain/spotify_playback_service.dart';

class SpotifyWebPlaybackService implements SpotifyPlaybackService {
  SpotifyWebPlaybackService({
    required SpotifyAppConfig config,
    required SpotifyAuthService authService,
    http.Client? httpClient,
    DateTime Function()? now,
  }) : _config = config,
       _authService = authService,
       _httpClient = httpClient ?? http.Client(),
       _now = now ?? DateTime.now;

  final SpotifyAppConfig _config;
  final SpotifyAuthService _authService;
  final http.Client _httpClient;
  final DateTime Function() _now;

  SpotifyPlaybackState _state = const SpotifyPlaybackState();

  @override
  Future<SpotifyPlaybackState> loadAvailableDevices() async {
    final token = await _authService.getValidAccessToken();
    if (token == null) {
      _state = _state.copyWith(
        availableDevices: const <SpotifyDevice>[],
        selectedDeviceId: null,
        playbackErrorCode: 'spotify-not-connected',
        playbackError: 'Spotify ist nicht verbunden.',
        lastSyncedAt: _now(),
      );
      return _state;
    }

    final response = await _httpClient.get(
      Uri.parse('${_config.apiBaseUrl}/me/player/devices'),
      headers: <String, String>{'Authorization': 'Bearer $token'},
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      _state = _state.copyWith(
        availableDevices: const <SpotifyDevice>[],
        selectedDeviceId: null,
        playbackErrorCode: 'device-load-failed',
        playbackError:
            'Spotify-Geraete konnten nicht geladen werden (${response.statusCode}).',
        lastSyncedAt: _now(),
      );
      return _state;
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final devices =
        ((payload['devices'] as List<dynamic>? ?? const <dynamic>[])
                .whereType<Map<String, dynamic>>()
                .map(_parseDevice)
                .toList())
            .cast<SpotifyDevice>();

    final currentSelection = _state.selectedDeviceId;
    final preservedSelection =
        currentSelection != null &&
            devices.any((device) => device.id == currentSelection)
        ? currentSelection
        : null;
    final activeDeviceId = devices
        .cast<SpotifyDevice?>()
        .firstWhere((device) => device?.isActive == true, orElse: () => null)
        ?.id;
    final selectedDeviceId = preservedSelection ?? activeDeviceId;
    final decoratedDevices = devices
        .map(
          (device) => device.copyWith(
            isActive: selectedDeviceId == null
                ? device.isActive
                : device.id == selectedDeviceId,
          ),
        )
        .toList();

    final noDevices = decoratedDevices.isEmpty;
    final lostSelection =
        currentSelection != null && selectedDeviceId == null && !noDevices;

    _state = _state.copyWith(
      availableDevices: decoratedDevices,
      selectedDeviceId: selectedDeviceId,
      playbackErrorCode: noDevices
          ? 'no-device'
          : lostSelection
          ? 'device-unavailable'
          : selectedDeviceId == null
          ? 'device-selection-required'
          : null,
      playbackError: noDevices
          ? 'Kein Spotify-Wiedergabegeraet verfuegbar.'
          : lostSelection
          ? 'Das zuvor ausgewaehlte Geraet ist nicht mehr verfuegbar.'
          : selectedDeviceId == null
          ? 'Bitte ein Wiedergabegeraet fuer den Host auswaehlen.'
          : null,
      lastSyncedAt: _now(),
    );

    return _state;
  }

  @override
  Future<SpotifyPlaybackState> selectDevice(String deviceId) async {
    final token = await _authService.getValidAccessToken();
    if (token == null) {
      _state = _state.copyWith(
        playbackErrorCode: 'spotify-not-connected',
        playbackError: 'Spotify ist nicht verbunden.',
        lastSyncedAt: _now(),
      );
      return _state;
    }

    final availableDevices = _state.availableDevices.isEmpty
        ? (await loadAvailableDevices()).availableDevices
        : _state.availableDevices;
    final targetExists = availableDevices.any(
      (device) => device.id == deviceId,
    );
    if (!targetExists) {
      _state = _state.copyWith(
        selectedDeviceId: null,
        playbackErrorCode: 'device-unavailable',
        playbackError: 'Das ausgewaehlte Geraet ist nicht mehr verfuegbar.',
        lastSyncedAt: _now(),
      );
      return _state;
    }

    final response = await _httpClient.put(
      Uri.parse('${_config.apiBaseUrl}/me/player'),
      headers: <String, String>{
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(<String, Object>{
        'device_ids': <String>[deviceId],
        'play': false,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      _state = _state.copyWith(
        selectedDeviceId: null,
        playbackErrorCode: 'device-selection-failed',
        playbackError:
            'Spotify-Geraet konnte nicht aktiviert werden (${response.statusCode}).',
        lastSyncedAt: _now(),
      );
      return _state;
    }

    _state = _state.copyWith(
      availableDevices: _state.availableDevices
          .map((device) => device.copyWith(isActive: device.id == deviceId))
          .toList(),
      selectedDeviceId: deviceId,
      playbackErrorCode: null,
      playbackError: null,
      lastSyncedAt: _now(),
    );
    return _state;
  }

  @override
  Future<PlaybackCommandResult> playTrack(SpotifyTrack track) async {
    final commandState = await _runPlaybackCommand(
      endpoint: '/me/player/play',
      commandName: 'play',
      body: <String, Object>{
        'uris': <String>[_trackUri(track)],
      },
    );
    if (!commandState.$1) {
      return PlaybackCommandResult.failure(
        errorCode: commandState.$2 ?? 'playback-command-failed',
        errorMessage:
            commandState.$3 ?? 'Spotify-Playback konnte nicht gestartet werden.',
        effectiveDeviceId: _state.selectedDeviceId,
      );
    }
    _state = _state.copyWith(
      actualNowPlayingTrackId: track.id,
      actualProgressMs: 0,
      actualDurationMs: null,
      actualIsPaused: false,
      lastCommand: 'play',
      playbackErrorCode: null,
      playbackError: null,
      lastSyncedAt: _now(),
    );
    return PlaybackCommandResult.success(
      effectiveTrackId: track.id,
      effectiveDeviceId: _state.selectedDeviceId,
    );
  }

  @override
  Future<PlaybackCommandResult> pause() async {
    final commandState = await _runPlaybackCommand(
      endpoint: '/me/player/pause',
      commandName: 'pause',
    );
    if (!commandState.$1) {
      return PlaybackCommandResult.failure(
        errorCode: commandState.$2 ?? 'playback-command-failed',
        errorMessage:
            commandState.$3 ?? 'Spotify-Playback konnte nicht pausiert werden.',
        effectiveDeviceId: _state.selectedDeviceId,
      );
    }
    _state = _state.copyWith(
      actualIsPaused: true,
      lastCommand: 'pause',
      playbackErrorCode: null,
      playbackError: null,
      lastSyncedAt: _now(),
    );
    return PlaybackCommandResult.success(
      effectiveTrackId: _state.actualNowPlayingTrackId,
      effectiveDeviceId: _state.selectedDeviceId,
    );
  }

  @override
  Future<SpotifyPlaybackState> refreshPlaybackState() async {
    final token = await _authService.getValidAccessToken();
    if (token == null) {
      _state = _state.copyWith(
        playbackErrorCode: 'spotify-not-connected',
        playbackError: 'Spotify ist nicht verbunden.',
        lastSyncedAt: _now(),
      );
      return _state;
    }

    final response = await _httpClient.get(
      Uri.parse('${_config.apiBaseUrl}/me/player'),
      headers: <String, String>{'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 204) {
      _state = _state.copyWith(
        actualNowPlayingTrackId: null,
        actualProgressMs: null,
        actualDurationMs: null,
        actualIsPaused: true,
        playbackErrorCode: null,
        playbackError: null,
        lastSyncedAt: _now(),
      );
      return _state;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _state = _state.copyWith(
        playbackErrorCode: 'playback-state-load-failed',
        playbackError:
            'Spotify-Playback-Status konnte nicht geladen werden (${response.statusCode}).',
        lastSyncedAt: _now(),
      );
      return _state;
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final currentDevice = _parseDevice(
      (payload['device'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
    );
    final mergedDevices = _mergeDevicesWithCurrent(currentDevice);
    final track = payload['item'] as Map<String, dynamic>?;
    _state = _state.copyWith(
      availableDevices: mergedDevices,
      selectedDeviceId: currentDevice.id.isEmpty ? _state.selectedDeviceId : currentDevice.id,
      actualNowPlayingTrackId: (track?['id'] as String?)?.trim(),
      actualProgressMs: (payload['progress_ms'] as num?)?.toInt(),
      actualDurationMs: (track?['duration_ms'] as num?)?.toInt(),
      actualIsPaused: payload['is_playing'] == true ? false : true,
      playbackErrorCode: null,
      playbackError: null,
      lastSyncedAt: _now(),
    );
    return _state;
  }

  @override
  Future<PlaybackCommandResult> resume() async {
    final commandState = await _runPlaybackCommand(
      endpoint: '/me/player/play',
      commandName: 'resume',
    );
    if (!commandState.$1) {
      return PlaybackCommandResult.failure(
        errorCode: commandState.$2 ?? 'playback-command-failed',
        errorMessage:
            commandState.$3 ??
            'Spotify-Playback konnte nicht fortgesetzt werden.',
        effectiveDeviceId: _state.selectedDeviceId,
      );
    }
    _state = _state.copyWith(
      actualIsPaused: false,
      lastCommand: 'resume',
      playbackErrorCode: null,
      playbackError: null,
      lastSyncedAt: _now(),
    );
    return PlaybackCommandResult.success(
      effectiveTrackId: _state.actualNowPlayingTrackId,
      effectiveDeviceId: _state.selectedDeviceId,
    );
  }

  @override
  Future<PlaybackCommandResult> skip() async {
    final commandState = await _runPlaybackCommand(
      endpoint: '/me/player/next',
      commandName: 'skip',
      method: 'POST',
    );
    if (!commandState.$1) {
      return PlaybackCommandResult.failure(
        errorCode: commandState.$2 ?? 'playback-command-failed',
        errorMessage:
            commandState.$3 ?? 'Spotify-Playback konnte nicht uebersprungen werden.',
        effectiveDeviceId: _state.selectedDeviceId,
      );
    }
    _state = _state.copyWith(
      actualIsPaused: false,
      lastCommand: 'skip',
      playbackErrorCode: null,
      playbackError: null,
      lastSyncedAt: _now(),
    );
    return PlaybackCommandResult.success(
      effectiveTrackId: _state.actualNowPlayingTrackId,
      effectiveDeviceId: _state.selectedDeviceId,
    );
  }

  Future<(bool, String?, String?)> _runPlaybackCommand({
    required String endpoint,
    required String commandName,
    String method = 'PUT',
    Map<String, Object>? body,
  }) async {
    final token = await _authService.getValidAccessToken();
    if (token == null) {
      _state = _state.copyWith(
        playbackErrorCode: 'spotify-not-connected',
        playbackError: 'Spotify ist nicht verbunden.',
        lastSyncedAt: _now(),
      );
      return (false, 'spotify-not-connected', 'Spotify ist nicht verbunden.');
    }

    final deviceId = _state.selectedDeviceId;
    if (deviceId == null || deviceId.isEmpty) {
      _state = _state.copyWith(
        playbackErrorCode: 'no-device',
        playbackError: 'Kein aktives Wiedergabegeraet ausgewaehlt.',
        lastSyncedAt: _now(),
      );
      return (
        false,
        'no-device',
        'Kein aktives Wiedergabegeraet ausgewaehlt.',
      );
    }

    final uri = Uri.parse('${_config.apiBaseUrl}$endpoint').replace(
      queryParameters: <String, String>{'device_id': deviceId},
    );
    final requestHeaders = <String, String>{
      'Authorization': 'Bearer $token',
      if (body != null) 'Content-Type': 'application/json',
    };
    final response = switch (method) {
      'POST' => await _httpClient.post(
        uri,
        headers: requestHeaders,
        body: body == null ? null : jsonEncode(body),
      ),
      _ => await _httpClient.put(
        uri,
        headers: requestHeaders,
        body: body == null ? null : jsonEncode(body),
      ),
    };

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return (true, null, null);
    }

    if (response.statusCode == 404) {
      _state = _state.copyWith(
        selectedDeviceId: null,
        playbackErrorCode: 'device-unavailable',
        playbackError: 'Das ausgewaehlte Geraet ist nicht mehr verfuegbar.',
        lastSyncedAt: _now(),
      );
      return (
        false,
        'device-unavailable',
        'Das ausgewaehlte Geraet ist nicht mehr verfuegbar.',
      );
    }

    final message =
        'Spotify-$commandName fehlgeschlagen (${response.statusCode}).';
    _state = _state.copyWith(
      playbackErrorCode: 'playback-command-failed',
      playbackError: message,
      lastSyncedAt: _now(),
    );
    return (false, 'playback-command-failed', message);
  }

  String _trackUri(SpotifyTrack track) {
    final uri = track.uri?.trim();
    if (uri != null && uri.isNotEmpty) {
      return uri;
    }
    return 'spotify:track:${track.id}';
  }

  List<SpotifyDevice> _mergeDevicesWithCurrent(SpotifyDevice currentDevice) {
    final devicesById = <String, SpotifyDevice>{
      for (final device in _state.availableDevices) device.id: device,
    };
    if (currentDevice.id.isNotEmpty) {
      devicesById[currentDevice.id] = currentDevice;
    }
    final selectedDeviceId = currentDevice.id.isNotEmpty
        ? currentDevice.id
        : _state.selectedDeviceId;
    return devicesById.values
        .map(
          (device) => device.copyWith(
            isActive: selectedDeviceId != null && device.id == selectedDeviceId,
          ),
        )
        .toList();
  }

  SpotifyDevice _parseDevice(Map<String, dynamic> json) {
    return SpotifyDevice(
      id: (json['id'] as String?)?.trim() ?? '',
      name: (json['name'] as String?)?.trim().isNotEmpty == true
          ? (json['name'] as String).trim()
          : 'Unbenanntes Geraet',
      type: (json['type'] as String?)?.trim() ?? 'unknown',
      isActive: json['is_active'] == true,
    );
  }
}
