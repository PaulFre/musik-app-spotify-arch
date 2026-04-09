import 'package:flutter/material.dart';
import 'package:party_queue_app/src/features/settings/presentation/settings_scope.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = SettingsScope.of(context);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Einstellungen')),
          body: ListView(
            children: [
              const SizedBox(height: 8),
              ListTile(
                title: const Text('Dark Mode'),
                trailing: SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text('System'),
                    ),
                    ButtonSegment(value: ThemeMode.light, label: Text('Hell')),
                    ButtonSegment(value: ThemeMode.dark, label: Text('Dunkel')),
                  ],
                  selected: <ThemeMode>{controller.themeMode},
                  onSelectionChanged: (selection) =>
                      controller.setThemeMode(selection.first),
                ),
              ),
              ListTile(
                title: const Text('Sprache'),
                trailing: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'de', label: Text('DE')),
                    ButtonSegment(value: 'en', label: Text('EN')),
                  ],
                  selected: <String>{controller.locale.languageCode},
                  onSelectionChanged: (selection) {
                    controller.setLocale(Locale(selection.first));
                  },
                ),
              ),
              ListTile(
                title: const Text('Standard-Cooldown'),
                subtitle: Text('${controller.defaultCooldownMinutes} Minuten'),
                trailing: DropdownButton<int>(
                  value: controller.defaultCooldownMinutes,
                  items: const [0, 15, 30, 60]
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text('$value'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      controller.setDefaultCooldownMinutes(value);
                    }
                  },
                ),
              ),
              SwitchListTile(
                title: const Text('Benachrichtigungen'),
                value: controller.notificationsEnabled,
                onChanged: controller.setNotificationsEnabled,
              ),
            ],
          ),
        );
      },
    );
  }
}
