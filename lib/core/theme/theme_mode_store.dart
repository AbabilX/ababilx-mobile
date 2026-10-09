import 'package:shared_preferences/shared_preferences.dart';

import 'theme_mode_provider.dart';

/// Persists the user's theme choice. Device-local, same pattern as chat
/// wallpaper — no reason a theme choice needs a server round trip.
///
/// `null` means "no explicit choice" — follow the OS, same as before the
/// toggle existed.
class ThemeModeStore {
  const ThemeModeStore();

  static const _key = 'ababilx_theme_mode';
  static const _system = 'system';
  static const _light = 'light';
  static const _dark = 'dark';
  static const _lightsOut = 'lightsOut';

  Future<AppThemeMode?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key);
    switch (value) {
      case _dark:
        return AppThemeMode.dark;
      case _light:
        return AppThemeMode.light;
      case _lightsOut:
        return AppThemeMode.lightsOut;
      case _system:
        return AppThemeMode.system;
      default:
        return null;
    }
  }

  /// `AppThemeMode.system` clears back to system.
  Future<void> write(AppThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    if (mode == AppThemeMode.system) {
      await prefs.setString(_key, _system);
    } else {
      final value = switch (mode) {
        AppThemeMode.light => _light,
        AppThemeMode.dark => _dark,
        AppThemeMode.lightsOut => _lightsOut,
        AppThemeMode.system => _system,
      };
      await prefs.setString(_key, value);
    }
  }
}
