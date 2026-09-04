import 'package:shared_preferences/shared_preferences.dart';

/// What the user has already been asked, and answered, about battery.
class NotificationVitalsPrefs {
  const NotificationVitalsPrefs._();

  static const _dismissedKey = 'notif_battery_prompt_dismissed_v1';
  static const _lastPromptKey = 'notif_battery_prompt_at_v1';

  static SharedPreferencesAsync get _prefs => SharedPreferencesAsync();

  /// Set by either button on the prompt — the ask is answered either way, and
  /// the settings tile is where anyone who changes their mind goes.
  static Future<bool> dismissed() async {
    try {
      return await _prefs.getBool(_dismissedKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> markDismissed() async {
    try {
      await _prefs.setBool(_dismissedKey, true);
    } catch (_) {}
  }

  static Future<DateTime?> lastPromptAt() async {
    try {
      final ms = await _prefs.getInt(_lastPromptKey);
      return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
    } catch (_) {
      return null;
    }
  }

  static Future<void> markPrompted() async {
    try {
      await _prefs.setInt(
        _lastPromptKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {}
  }
}
