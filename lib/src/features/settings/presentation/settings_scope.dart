import 'package:flutter/material.dart';
import 'package:party_queue_app/src/features/settings/application/settings_controller.dart';

class SettingsScope extends InheritedWidget {
  const SettingsScope({
    super.key,
    required this.controller,
    required super.child,
  });

  final SettingsController controller;

  static SettingsController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SettingsScope>();
    assert(scope != null, 'SettingsScope not found in widget tree.');
    return scope!.controller;
  }

  @override
  bool updateShouldNotify(covariant SettingsScope oldWidget) {
    return oldWidget.controller != controller;
  }
}
