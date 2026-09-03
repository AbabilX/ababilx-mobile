import 'package:shared_preferences/shared_preferences.dart';

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

  Future<bool?> read() async {
    final prefs = await SharedPreferences.getInstance();
    switch (prefs.getString(_key)) {
      case _dark:
        return true;
      case _light:
        return false;
      default:
        return null;
    }
  }

  /// `null` clears back to system.
  Future<void> write(bool? isDark) async {
    final prefs = await SharedPreferences.getInstance();
    if (isDark == null) {
      await prefs.setString(_key, _system);
    } else {
      await prefs.setString(_key, isDark ? _dark : _light);
    }
  }
}
