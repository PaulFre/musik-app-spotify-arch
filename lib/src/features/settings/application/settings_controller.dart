import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsController extends ChangeNotifier {
  static const String _themeModeKey = 'settings.theme_mode';
  static const String _localeKey = 'settings.locale';

  ThemeMode _themeMode = ThemeMode.light;
  Locale _locale = const Locale('de');
  int _defaultCooldownMinutes = 15;
  bool _notificationsEnabled = true;

  ThemeMode get themeMode => _themeMode;
  Locale get locale => _locale;
  int get defaultCooldownMinutes => _defaultCooldownMinutes;
  bool get notificationsEnabled => _notificationsEnabled;

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final savedThemeMode = prefs.getString(_themeModeKey);
    final restoredThemeMode = _themeModeFromStorage(savedThemeMode);
    final savedLocale = prefs.getString(_localeKey);
    final restoredLocale = _localeFromStorage(savedLocale);
    if (restoredThemeMode == _themeMode && restoredLocale == _locale) {
      return;
    }
    _themeMode = restoredThemeMode;
    _locale = restoredLocale;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final normalizedMode = _normalizeThemeMode(mode);
    if (_themeMode == normalizedMode) {
      return;
    }
    _themeMode = normalizedMode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, _themeModeToStorage(normalizedMode));
  }

  Future<void> setLocale(Locale locale) async {
    final normalizedLocale = _normalizeLocale(locale);
    if (_locale == normalizedLocale) {
      return;
    }
    _locale = normalizedLocale;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, normalizedLocale.languageCode);
  }

  void setDefaultCooldownMinutes(int minutes) {
    _defaultCooldownMinutes = minutes;
    notifyListeners();
  }

  void setNotificationsEnabled(bool enabled) {
    _notificationsEnabled = enabled;
    notifyListeners();
  }

  String _themeModeToStorage(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'light';
    }
  }

  ThemeMode _themeModeFromStorage(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      case null:
        return ThemeMode.light;
      default:
        return ThemeMode.light;
    }
  }

  ThemeMode _normalizeThemeMode(ThemeMode mode) {
    if (mode == ThemeMode.system) {
      return ThemeMode.light;
    }
    return mode;
  }

  Locale _localeFromStorage(String? value) {
    switch (value) {
      case 'en':
        return const Locale('en');
      case 'de':
      case null:
        return const Locale('de');
      default:
        return const Locale('de');
    }
  }

  Locale _normalizeLocale(Locale locale) {
    if (locale.languageCode == 'en') {
      return const Locale('en');
    }
    return const Locale('de');
  }
}
