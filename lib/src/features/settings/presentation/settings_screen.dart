import 'package:flutter/material.dart';
import 'package:party_queue_app/src/app/app_strings.dart';
import 'package:party_queue_app/src/features/settings/presentation/settings_scope.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = SettingsScope.of(context);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final strings = context.strings;
        return Scaffold(
          appBar: AppBar(title: Text(strings.settings)),
          body: ListView(
            children: [
              const SizedBox(height: 8),
              ListTile(
                title: Text(strings.themeMode),
                trailing: SegmentedButton<ThemeMode>(
                  segments: [
                    ButtonSegment(
                      value: ThemeMode.light,
                      label: Text(strings.light),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      label: Text(strings.dark),
                    ),
                  ],
                  selected: <ThemeMode>{controller.themeMode},
                  onSelectionChanged: (selection) =>
                      controller.setThemeMode(selection.first),
                ),
              ),
              ListTile(
                title: Text(strings.language),
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
                title: Text(strings.defaultCooldown),
                subtitle: Text(
                  strings.minutes(controller.defaultCooldownMinutes),
                ),
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
                title: Text(strings.notifications),
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
