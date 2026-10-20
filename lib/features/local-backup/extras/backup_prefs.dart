import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'backup_pref_merge.dart';

/// The app settings a backup carries — Signal's backup restores the person's
/// preferences with their messages, so a new phone feels like the old one.
///
/// An allowlist, never "every key": most stored values describe THIS install
/// (push token, device id, caches, prompts already shown, the backup folder's
/// grant) and would be wrong or harmful on another one. Chat-lock passwords
/// are not here either: their hashes live behind the Keystore and a guessable
/// password must not leave it (see [restoredLockIndex]).
abstract final class BackupPrefs {
  static const exact = {
    'ababilx_theme_mode',
    'media_quality',
    'decline_message',
    'ababilx_chat_wallpaper_global',
    wallpaperPhotos,
    'chat_notif_hidden_text_v1',
    lockIndex,
  };

  static const prefixes = [
    'ababilx_chat_wallpaper_',
    'auto_download_',
    'ababilx_contact_nickname_',
    'ababilx_peer_fingerprint_v1_',
    'call_favorites_v1:',
  ];

  static const wallpaperPhotos = 'ababilx_wallpaper_photos_v1';
  static const lockIndex = 'chat_locks_v1';

  static bool allowed(String key) =>
      exact.contains(key) || prefixes.any(key.startsWith);

  /// Every allowed value on this phone as a `pref` frame. `s` names the
  /// store it came from: `l` the legacy SharedPreferences file, `a`
  /// [SharedPreferencesAsync] (a separate store on Android).
  static Future<List<Map<String, dynamic>>> export() async {
    final frames = <Map<String, dynamic>>[];
    try {
      final legacy = await SharedPreferences.getInstance();
      for (final key in legacy.getKeys()) {
        if (allowed(key)) _add(frames, 'l', key, legacy.get(key));
      }
    } catch (error) {
      debugPrint('[LocalBackup] prefs (legacy) unreadable: $error');
    }
    try {
      final all = await SharedPreferencesAsync().getAll();
      for (final e in all.entries) {
        if (allowed(e.key)) _add(frames, 'a', e.key, e.value);
      }
    } catch (error) {
      debugPrint('[LocalBackup] prefs (async) unreadable: $error');
    }
    return frames;
  }

  static void _add(
    List<Map<String, dynamic>> out,
    String store,
    String key,
    Object? value,
  ) {
    final type = switch (value) {
      String() => 's',
      bool() => 'b',
      int() => 'i',
      double() => 'd',
      List() => 'l',
      _ => null,
    };
    if (type == null) return;
    out.add({'t': 'pref', 's': store, 'k': key, 'y': type, 'v': value});
  }

  /// Writes the restored values. **A value already on this phone wins** — a
  /// restore normally lands on a new install, where nothing is set; on the
  /// same phone (after "start fresh") a choice made since the backup is newer
  /// than the backup's. Locks merge instead: a chat locked on either side
  /// stays locked; so do the lists in [BackupPrefMerge] (favourites, kept
  /// wallpaper photos). [rewrite] maps a stored path to where its file landed.
  static Future<int> restore(
    List<Map<String, dynamic>> frames, {
    required String Function(String value) rewrite,
  }) async {
    final legacy = await SharedPreferences.getInstance();
    final async = SharedPreferencesAsync();
    var written = 0;
    for (final f in frames) {
      final key = f['k'];
      if (key is! String || !allowed(key)) continue;
      try {
        final isAsync = f['s'] == 'a';
        final present = isAsync
            ? await async.containsKey(key)
            : legacy.containsKey(key);
        if (key == lockIndex) {
          await _restoreLocks(async, f['v']);
          written++;
          continue;
        }
        var value = _value(f['y'], f['v'], rewrite);
        if (value == null) continue;
        if (present) {
          if (!BackupPrefMerge.merges(key)) continue;
          final phone = isAsync
              ? await _readAsync(async, key)
              : legacy.get(key);
          value = BackupPrefMerge.merge(key, phone, value);
          if (value == null) continue;
        }
        await (isAsync
            ? _writeAsync(async, key, value)
            : _write(legacy, key, value));
        written++;
      } catch (error) {
        debugPrint('[LocalBackup] pref $key not restored: $error');
      }
    }
    return written;
  }

  static Object? _value(Object? type, Object? v, String Function(String) rw) =>
      switch (type) {
        's' when v is String => rw(v),
        'b' when v is bool => v,
        'i' when v is num => v.toInt(),
        'd' when v is num => v.toDouble(),
        'l' when v is List => [for (final s in v) rw(s.toString())],
        _ => null,
      };

  static Future<Object?> _write(SharedPreferences p, String k, Object v) =>
      switch (v) {
        String() => p.setString(k, v),
        bool() => p.setBool(k, v),
        int() => p.setInt(k, v),
        double() => p.setDouble(k, v),
        List<String>() => p.setStringList(k, v),
        _ => Future.value(false),
      };

  static Future<void> _writeAsync(
    SharedPreferencesAsync p,
    String k,
    Object v,
  ) => switch (v) {
    String() => p.setString(k, v),
    bool() => p.setBool(k, v),
    int() => p.setInt(k, v),
    double() => p.setDouble(k, v),
    List<String>() => p.setStringList(k, v),
    _ => Future<void>.value(),
  };

  static Future<Object?> _readAsync(SharedPreferencesAsync p, String k) async =>
      (await p.getAll(allowList: {k}))[k];

  static Future<void> _restoreLocks(SharedPreferencesAsync p, Object? v) async {
    if (v is! String) return;
    final current = await p.getString(lockIndex);
    final merged = restoredLockIndex(v, current);
    if (merged != null) await p.setString(lockIndex, merged);
  }
}

/// Union of the backup's locks and this phone's, as `chat_locks_v1` JSON.
/// A backed-up password lock comes back as the phone's own lock: the
/// password's hash never left the old phone's Keystore, and a chat that was
/// locked must not open bare. The phone's current entries win.
@visibleForTesting
String? restoredLockIndex(String backup, String? current) {
  try {
    final restored = jsonDecode(backup);
    if (restored is! Map) return null;
    final now = current == null || current.isEmpty ? {} : jsonDecode(current);
    final out = <String, String>{
      for (final e in restored.entries)
        if (e.value == 'device' || e.value == 'password')
          e.key.toString(): 'device',
      if (now is Map)
        for (final e in now.entries) e.key.toString(): e.value.toString(),
    };
    return out.isEmpty ? null : jsonEncode(out);
  } catch (_) {
    return null;
  }
}
