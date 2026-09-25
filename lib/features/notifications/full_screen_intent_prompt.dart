import 'dart:io' show Platform;

import 'package:flutter/widgets.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_version.dart';
import '../calls/native/android_call_lock_screen.dart';
import 'fcm_log.dart';

/// Whether now is a moment to send the user to Android 14's "full-screen
/// notifications" page.
///
/// That page is an ordinary Activity. Opened on a locked phone it asks for
/// the PIN first; opened by the cold start an Accept caused, it covers the
/// call. It used to open on every cold start where the permission was off —
/// which, after a Play update or a fresh install, is exactly when it is off:
/// "I have to unlock the phone to answer". Once per build, and only when the
/// person is looking at the unlocked app with no call up.
bool shouldAskFullScreenIntent({
  required bool locked,
  required bool callLive,
  required bool foreground,
  required int? askedBuild,
  required int build,
}) => !locked && !callLive && foreground && askedBuild != build;

class FullScreenIntentPrompt {
  FullScreenIntentPrompt._();

  static const _askedKey = 'full_screen_intent_asked_build_v1';

  /// [callLive] is read at the last moment: a call may ring while this waits.
  static Future<void> maybeAsk({required bool Function() callLive}) async {
    if (!Platform.isAndroid) return;
    try {
      if (await FlutterCallkitIncoming.canUseFullScreenIntent()) return;
      final prefs = SharedPreferencesAsync();
      final lock = await AndroidCallLockScreen.read();
      final ask = shouldAskFullScreenIntent(
        locked: lock.locked,
        callLive: callLive(),
        foreground:
            WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed,
        askedBuild: await prefs.getInt(_askedKey),
        build: appBuildNumber,
      );
      fcmLog('permission.full_screen', 'ask=$ask');
      if (!ask) return;
      await prefs.setInt(_askedKey, appBuildNumber);
      await FlutterCallkitIncoming.requestFullIntentPermission();
    } catch (error) {
      fcmLog('permission.full_screen.fail', error);
    }
  }
}
