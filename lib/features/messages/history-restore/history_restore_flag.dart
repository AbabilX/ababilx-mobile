import 'package:shared_preferences/shared_preferences.dart';

/// Device-local bits for the one recovery restore on this install.
///
/// `pending` — recovery code just unlocked the vault; a run should start (or
/// resume if the process was killed mid-run).
/// `done` — that run has finished. Nothing starts again until sign-out, even
/// if some chats were empty or the user later opens the app a hundred times.
class HistoryRestoreFlag {
  static const pendingPrefix = 'chat_history_restore_pending_';
  static const donePrefix = 'chat_history_restore_done_';

  static String _pendingKey(String userId) => '$pendingPrefix$userId';
  static String _doneKey(String userId) => '$donePrefix$userId';

  static Future<void> mark(String userId) async {
    final id = userId.trim();
    if (id.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_doneKey(id)) ?? false) return;
    await prefs.setBool(_pendingKey(id), true);
  }

  static Future<bool> isPending(String userId) async {
    final id = userId.trim();
    if (id.isEmpty) return false;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_doneKey(id)) ?? false) return false;
    return prefs.getBool(_pendingKey(id)) ?? false;
  }

  static Future<void> complete(String userId) async {
    final id = userId.trim();
    if (id.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingKey(id));
    await prefs.setBool(_doneKey(id), true);
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where(
      (key) => key.startsWith(pendingPrefix) || key.startsWith(donePrefix),
    );
    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}
