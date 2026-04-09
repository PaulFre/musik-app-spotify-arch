import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:party_queue_app/src/features/home/presentation/home_screen.dart';
import 'package:party_queue_app/src/features/settings/application/settings_controller.dart';
import 'package:party_queue_app/src/features/settings/presentation/settings_scope.dart';

class PartyQueueApp extends StatefulWidget {
  const PartyQueueApp({super.key});

  @override
  State<PartyQueueApp> createState() => _PartyQueueAppState();
}

class _PartyQueueAppState extends State<PartyQueueApp> {
  final SettingsController _settingsController = SettingsController();

  @override
  void dispose() {
    _settingsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScope(
      controller: _settingsController,
      child: AnimatedBuilder(
        animation: _settingsController,
        builder: (context, _) {
          return MaterialApp(
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
