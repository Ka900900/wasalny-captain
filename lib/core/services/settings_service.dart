import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:waslny_captain/core/services/notification_service.dart';
import 'package:waslny_captain/core/utils/logger.dart';

class SettingsService extends ChangeNotifier {
  SettingsService._();

  static final SettingsService instance = SettingsService._();

  static const String _themeModeKey = 'app_theme_mode';
  static const String _notificationsKey = 'app_notifications_enabled';

  ThemeMode themeMode = ThemeMode.dark;
  bool notificationsEnabled = true;

  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(
        const Duration(seconds: 6),
      );
      final storedTheme = prefs.getString(_themeModeKey);
      themeMode = _themeModeFromString(storedTheme) ?? ThemeMode.dark;
      notificationsEnabled = prefs.getBool(_notificationsKey) ?? true;
    } catch (e) {
      logError('SettingsService', 'initialize failed/timed out: $e', e);
      themeMode = ThemeMode.dark;
      notificationsEnabled = true;
    }
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
    if (enabled) {
      await NotificationService.instance.enable();
    } else {
      await NotificationService.instance.disable();
    }
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
