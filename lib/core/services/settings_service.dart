import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService extends ChangeNotifier {
  SettingsService._();

  static final SettingsService instance = SettingsService._();

  static const String _themeModeKey = 'app_theme_mode';
  static const String _notificationsKey = 'app_notifications_enabled';

  ThemeMode themeMode = ThemeMode.system;
  bool notificationsEnabled = true;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final storedTheme = prefs.getString(_themeModeKey);
    themeMode = _themeModeFromString(storedTheme) ?? ThemeMode.system;
    notificationsEnabled = prefs.getBool(_notificationsKey) ?? true;
  }

  Future<void> updateThemeMode(ThemeMode mode) async {
    themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, _themeModeToString(mode));
    notifyListeners();
  }

  Future<void> updateNotificationsEnabled(bool enabled) async {
    notificationsEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationsKey, enabled);
    notifyListeners();
  }

  ThemeMode? _themeModeFromString(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      default:
        return null;
    }
  }

  String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }
}
