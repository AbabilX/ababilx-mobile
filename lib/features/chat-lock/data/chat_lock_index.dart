import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// How a locked chat opens: the phone's own lock, or a password set for that
/// one chat.
enum ChatLockMethod {
  device,
  password;

  static ChatLockMethod? fromWire(Object? value) => switch (value) {
    'device' => ChatLockMethod.device,
    'password' => ChatLockMethod.password,
    _ => null,
  };
}

/// Which conversations are locked on this phone, and how. Device-local on
/// purpose: a fingerprint belongs to a phone, and the server never learns a
/// chat is locked.
///
/// Not a secret — the passwords live in secure storage
/// ([ChatLockSecrets]). Kept in [SharedPreferencesAsync] so the FCM
/// background isolate reads what the app just wrote and hides a locked
/// chat's notification. [preload] runs before the first frame, so the chat
/// list can leave locked chats out synchronously instead of drawing them for
/// one frame.
abstract final class ChatLockIndex {
  static const _key = 'chat_locks_v1';
  static Map<String, ChatLockMethod>? _cache;

  static SharedPreferencesAsync get _prefs => SharedPreferencesAsync();

  /// What [preload] or the last [write] saw. Main isolate only.
  static Map<String, ChatLockMethod> get cached => _cache ?? const {};

  static Future<void> preload() async => _cache = await read();

  /// A fresh read — what the background isolate uses.
  static Future<Map<String, ChatLockMethod>> read() async {
    try {
      final raw = await _prefs.getString(_key);
      if (raw == null || raw.isEmpty) return const {};
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const {};
      return {
        for (final entry in decoded.entries)
          entry.key.toString(): ?ChatLockMethod.fromWire(entry.value),
      };
    } catch (_) {
      return const {};
    }
  }

  static Future<bool> isLocked(String conversationId) async =>
      conversationId.isNotEmpty && (await read()).containsKey(conversationId);

  static Future<void> write(Map<String, ChatLockMethod> locks) async {
    _cache = Map.unmodifiable(locks);
    await _prefs.setString(
      _key,
      jsonEncode({for (final e in locks.entries) e.key: e.value.name}),
    );
  }

  static Future<void> clearAll() async {
    _cache = const {};
    try {
      await _prefs.remove(_key);
    } catch (_) {}
  }
}
