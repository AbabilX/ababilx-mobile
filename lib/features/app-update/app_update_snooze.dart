import 'package:shared_preferences/shared_preferences.dart';

/// "Later" on an optional update hides that build for a day.
///
/// Keyed by build, so the next release prompts again at once. A required
/// update ignores this entirely.
class AppUpdateSnooze {
  AppUpdateSnooze._();

  static const _key = 'app_update_snoozed_v1';
  static const window = Duration(hours: 24);

  static Future<bool> isSnoozed(int build) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final parts = (prefs.getString(_key) ?? '').split(':');
      if (parts.length != 2 || int.tryParse(parts[0]) != build) return false;
      final at = int.tryParse(parts[1]) ?? 0;
      final age = DateTime.now().millisecondsSinceEpoch - at;
      return age >= 0 && age < window.inMilliseconds;
    } catch (_) {
      return false;
    }
  }

  static Future<void> snooze(int build) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        '$build:${DateTime.now().millisecondsSinceEpoch}',
      );
    } catch (_) {}
  }
}
