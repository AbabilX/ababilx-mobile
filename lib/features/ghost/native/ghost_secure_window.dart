import 'dart:io' show Platform;

import 'package:flutter/services.dart';

/// Blocks screenshots, screen recording and the recents thumbnail while a
/// Ghost Chat is on screen (Android `FLAG_SECURE`, `SecureWindowChannel.kt`).
///
/// Held for the whole session, invite and ended screen included, and released
/// only once the provider is idle again. A build without the native half
/// answers MissingPluginException, which is ignored: the chat still works, it
/// just cannot stop a screenshot.
abstract final class GhostSecureWindow {
  static const _channel = MethodChannel('com.ababilx.app/secure_window');
  static bool _held = false;

  /// Exactly one hold is ever taken, and exactly one released: the native side
  /// counts holds, so a repeated `set(true)` that slipped through would leave
  /// the count above zero for good and block screenshots app-wide.
  static Future<void> set(bool secure) async {
    if (!Platform.isAndroid || _held == secure) return;
    _held = secure;
    try {
      await _channel.invokeMethod<void>('setSecure', {'secure': secure});
    } on MissingPluginException {
      // Native half not in this build.
    } on PlatformException {
      // The call never reached the window, so this side did not take a hold.
      _held = !secure;
    }
  }
}
