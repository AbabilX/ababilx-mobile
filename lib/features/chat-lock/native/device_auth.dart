import 'dart:io' show Platform;

import 'package:flutter/services.dart';

enum DeviceAuthResult { ok, cancelled, failed, unavailable }

/// The phone's own lock — fingerprint, face or screen PIN — asked for by a
/// locked chat. `DeviceAuthChannel.kt` owns the prompt (framework
/// BiometricPrompt, no plugin). Android only: on iOS [available] is false and
/// a chat can only be locked with its own password.
abstract final class DeviceAuth {
  static const _channel = MethodChannel('com.ababilx.app/device_auth');

  /// True while a prompt is up. The prompt, and below API 29 the confirm
  /// screen, take the app out of the foreground; the lock session must not
  /// read that as the user leaving.
  static bool busy = false;

  /// Whether the phone has a screen lock at all. Without one there is
  /// nothing to ask, so the phone-lock option is offered but refused.
  static Future<bool> available() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('available') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  static Future<DeviceAuthResult> authenticate({
    required String title,
    String subtitle = '',
  }) async {
    if (!Platform.isAndroid) return DeviceAuthResult.unavailable;
    busy = true;
    try {
      final outcome = await _channel.invokeMethod<String>('authenticate', {
        'title': title,
        'subtitle': subtitle,
      });
      return switch (outcome) {
        'ok' => DeviceAuthResult.ok,
        'cancelled' || 'busy' => DeviceAuthResult.cancelled,
        'unavailable' => DeviceAuthResult.unavailable,
        _ => DeviceAuthResult.failed,
      };
    } on MissingPluginException {
      return DeviceAuthResult.unavailable;
    } on PlatformException {
      return DeviceAuthResult.failed;
    } finally {
      // The app comes back to the foreground a frame after the answer; the
      // session's resume check runs before this would otherwise be cleared.
      Future<void>.delayed(const Duration(seconds: 1), () => busy = false);
    }
  }
}
