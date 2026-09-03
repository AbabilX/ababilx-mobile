import 'dart:io' show Platform;

import 'package:flutter/services.dart';

/// Closes flutter_callkit_incoming's full-screen incoming Activity — the
/// surface a locked phone shows, which the plugin's own teardown cannot reach.
///
/// The plugin broadcasts its dismissal to an explicit component, and Android
/// never matches an explicit broadcast against a runtime-registered receiver,
/// so the Activity that registered one in `onCreate` outlives every end,
/// decline and hide. `CallkitSurface.kt` carries the full account.
///
/// Native `CallEventBridge` already calls the Kotlin side on accept / decline /
/// end, in every process. This exists for the one path that emits no CallKit
/// event at all: handing the ringing UI to the Flutter call screen.
///
/// No-op off Android: iOS's incoming UI is CallKit's own and dismisses itself.
class CallkitSurface {
  const CallkitSurface._();

  static const _channel = MethodChannel('com.ababilx.app/call_ringer');

  /// [accepted] mirrors the plugin's flag — an answered call closes a second
  /// later so its accept animation finishes, anything else closes at once.
  static Future<void> dismissIncoming({bool accepted = false}) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('dismissCallkitIncoming', {
        'accepted': accepted,
      });
    } on PlatformException {
      // A surface that will not close must not take the call down with it.
    } on MissingPluginException {
      // Engine without this plugin registered — nothing is showing there.
    }
  }
}
