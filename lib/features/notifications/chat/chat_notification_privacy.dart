import 'package:shared_preferences/shared_preferences.dart';

import '../../chat-lock/data/chat_lock_index.dart';

/// Which DMs draw nothing personal in the tray: no sender name, no text, no
/// photo — "AbabilX · New message". Two reasons put a chat here: the user
/// switched it on in the chat's settings, or the chat is locked (a locked
/// chat always hides it).
///
/// Device-local, like the lock: the phone draws its own chat notifications.
/// [SharedPreferencesAsync] so the FCM background isolate reads what the app
/// just wrote.
abstract final class ChatNotificationPrivacy {
  static const _key = 'chat_notif_hidden_text_v1';

  static SharedPreferencesAsync get _prefs => SharedPreferencesAsync();

  /// Chats the user switched to hidden text, not counting locked ones.
  static Future<Set<String>> chosen() async {
    try {
      return (await _prefs.getStringList(_key) ?? const []).toSet();
    } catch (_) {
      return {};
    }
  }

  static Future<void> setChosen(String conversationId, bool hidden) async {
    final ids = await chosen();
    hidden ? ids.add(conversationId) : ids.remove(conversationId);
    await _prefs.setStringList(_key, ids.toList());
  }

  /// What the presenter asks before drawing anything. A read failure hides:
  /// a notification with too little in it is the safe mistake.
  static Future<bool> isHidden(String conversationId) async {
    if (conversationId.isEmpty) return false;
    try {
      if ((await chosen()).contains(conversationId)) return true;
      return await ChatLockIndex.isLocked(conversationId);
    } catch (_) {
      return true;
    }
  }

  static Future<void> clearAll() async {
    try {
      await _prefs.remove(_key);
    } catch (_) {}
  }
}
