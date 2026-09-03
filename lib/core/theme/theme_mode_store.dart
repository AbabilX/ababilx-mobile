import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user's dark-mode toggle. Device-local, same pattern as chat
/// wallpaper — no reason a theme choice needs a server round trip.
class ThemeModeStore {
  const ThemeModeStore();

  static const _key = 'ababilx_dark_mode';

  Future<bool?> read() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_key) ? prefs.getBool(_key) : null;
  }

  Future<void> write(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, isDark);
  }
}
