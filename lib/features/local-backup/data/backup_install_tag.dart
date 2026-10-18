import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// A random token for this install of the app (see `BackupFolderView`).
///
/// SharedPreferences is the right home because it does NOT outlive the
/// install: Android backup is off for this app (AndroidManifest), so a
/// reinstall — the case the tag exists for — always gets a new one.
abstract final class BackupInstallTag {
  static const _key = 'local_backup_install_tag_v1';
  static String? _cached;

  static Future<String> value() async {
    final cached = _cached;
    if (cached != null) return cached;
    final prefs = await SharedPreferences.getInstance();
    var tag = prefs.getString(_key);
    if (tag == null || tag.isEmpty) {
      final random = Random.secure();
      tag = List.generate(
        16,
        (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
      await prefs.setString(_key, tag);
    }
    return _cached = tag;
  }
}
