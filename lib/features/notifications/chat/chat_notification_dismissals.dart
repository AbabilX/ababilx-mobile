import 'package:shared_preferences/shared_preferences.dart';

/// When each conversation was last read in the app, shared across isolates.
///
/// The FCM background isolate posts a placeholder, then spends seconds
/// decrypting and fetching a photo before it posts again. If the reader opens
/// the chat in that gap, the app cancels the entry and the background isolate
/// puts it straight back. A push can also arrive late, after the message was
/// already read. Both check this mark before drawing anything.
///
/// [SharedPreferencesAsync] for the same reason as the store: it reads through
/// to the platform, so the background isolate sees a mark the app just wrote.
class ChatNotificationDismissals {
  const ChatNotificationDismissals._();

  static const _prefix = 'chat_notif_read_v1_';

  static SharedPreferencesAsync get _prefs => SharedPreferencesAsync();

  static Future<void> mark(String conversationId) async {
    try {
      await _prefs.setInt(
        '$_prefix$conversationId',
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {}
  }

  /// True when the conversation was read at or after [since].
  static Future<bool> readSince(String conversationId, DateTime since) async {
    try {
      final at = await _prefs.getInt('$_prefix$conversationId');
      return at != null && at >= since.millisecondsSinceEpoch;
    } catch (_) {
      return false;
    }
  }

  static Future<void> clearAll() async {
    try {
      final keys = await _prefs.getKeys();
      for (final key in keys.where((value) => value.startsWith(_prefix))) {
        await _prefs.remove(key);
      }
    } catch (_) {}
  }
}
