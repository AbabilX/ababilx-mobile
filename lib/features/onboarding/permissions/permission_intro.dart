import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A row on the "Allow permissions" screen.
enum IntroPermission { notifications, microphone, media }

/// Signal-Android's `GrantPermissionsFragment` decision: once per install,
/// before the restore screen, explain what the app will ask for and ask it
/// all in one go — instead of OS dialogs firing at whatever moment a feature
/// first wanted one.
///
/// [settled] is what keeps the push setup from firing its own notification
/// dialog over this screen: `FcmBootstrap` waits for it, and skips the ask
/// when this screen already made it.
class PermissionIntro {
  const PermissionIntro._();

  static const _key = 'permission_intro_v1';
  static const answeredNext = 'next';
  static const answeredLater = 'later';

  static final Completer<bool> _settled = Completer<bool>();

  /// Completes once the screen was shown and answered (true) or will not be
  /// shown this launch (false).
  static Future<bool> get settled => _settled.future;

  static void settle({required bool shown}) {
    if (!_settled.isCompleted) _settled.complete(shown);
  }

  /// [answeredNext], [answeredLater], or null when never shown.
  static Future<String?> answer() async {
    try {
      return await SharedPreferencesAsync().getString(_key);
    } catch (_) {
      return null;
    }
  }

  /// The rows still worth asking for. A permission already granted (or one
  /// this Android version grants on install, like notifications below 13)
  /// has no row — Signal drops the notifications row below API 33 the same way.
  static Future<List<IntroPermission>> missing() async {
    final rows = <IntroPermission>[];
    for (final row in IntroPermission.values) {
      if (!await _granted(row)) rows.add(row);
    }
    return rows;
  }

  static Future<bool> shouldShow() async {
    if (await answer() != null) return false;
    return (await missing()).isNotEmpty;
  }

  /// Next: one system request for everything listed; the OS shows its
  /// dialogs back to back.
  static Future<void> grant(List<IntroPermission> rows) async {
    await _save(answeredNext);
    final asks = [for (final row in rows) ..._permissionsFor(row)];
    try {
      await asks.request().timeout(const Duration(minutes: 2));
    } catch (error) {
      debugPrint('[PermissionIntro] request failed: $error');
    }
  }

  /// Not now: nothing asked; each feature asks again when it is used.
  static Future<void> later() => _save(answeredLater);

  static List<Permission> _permissionsFor(IntroPermission row) => switch (row) {
    IntroPermission.notifications => [Permission.notification],
    IntroPermission.microphone => [Permission.microphone],
    // The same pair the in-app gallery asks for.
    IntroPermission.media => [Permission.photos, Permission.videos],
  };

  static Future<bool> _granted(IntroPermission row) async {
    try {
      final status = await _permissionsFor(row).first.status;
      return status.isGranted || status.isLimited;
    } catch (_) {
      return true;
    }
  }

  static Future<void> _save(String value) async {
    try {
      await SharedPreferencesAsync().setString(_key, value);
    } catch (_) {}
  }
}
