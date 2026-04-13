import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:party_queue_app/src/app/services.dart';
import 'package:party_queue_app/src/features/party/domain/join_input_parser.dart';
import 'package:party_queue_app/src/features/home/presentation/home_screen.dart';
import 'package:party_queue_app/src/features/party/presentation/join_room_screen.dart';
import 'package:party_queue_app/src/features/settings/application/settings_controller.dart';
import 'package:party_queue_app/src/features/settings/presentation/settings_scope.dart';

class PartyQueueApp extends StatefulWidget {
  const PartyQueueApp({super.key});

  @override
  State<PartyQueueApp> createState() => _PartyQueueAppState();
}

class _PartyQueueAppState extends State<PartyQueueApp> {
  final SettingsController _settingsController = SettingsController();
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<ParsedJoinInput>? _joinLinkSub;
  String? _lastHandledJoinRaw;

  @override
  void initState() {
    super.initState();
    unawaited(_settingsController.restore());
    unawaited(Services.spotifyConnectionController.restoreSession());
    _joinLinkSub = Services.appJoinLinkService.joinInputStream.listen(
      _routeToJoinFlow,
    );
    unawaited(_openInitialJoinLinkIfPresent());
  }

  @override
  void dispose() {
    _joinLinkSub?.cancel();
    _settingsController.dispose();
    super.dispose();
  }

  Future<void> _openInitialJoinLinkIfPresent() async {
    final joinInput = await Services.appJoinLinkService.getInitialJoinInput();
    if (joinInput != null) {
      _routeToJoinFlow(joinInput);
    }
  }

  void _routeToJoinFlow(ParsedJoinInput joinInput) {
    if (_lastHandledJoinRaw == joinInput.raw) {
      return;
    }
    _lastHandledJoinRaw = joinInput.raw;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final navigator = _navigatorKey.currentState;
      if (navigator == null) {
        return;
      }
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) =>
              JoinRoomScreen(initialJoinInput: joinInput.normalizedCode),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScope(
      controller: _settingsController,
      child: AnimatedBuilder(
        animation: _settingsController,
        builder: (context, _) {
          return MaterialApp(
            key: ValueKey<String>(_settingsController.locale.languageCode),
            navigatorKey: _navigatorKey,
            title: 'Party Queue',
            locale: _settingsController.locale,
            supportedLocales: const [Locale('de'), Locale('en')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            themeMode: _settingsController.themeMode,
            darkTheme: ThemeData.dark(useMaterial3: true),
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
            ),
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}
