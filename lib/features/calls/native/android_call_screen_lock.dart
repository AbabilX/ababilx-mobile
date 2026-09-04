import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

/// What a live call does to the display, driven from Dart.
///
/// Two separate things with two separate lifetimes, which is why they are two
/// calls rather than one "call is running" flag:
///
/// - [setEarpieceCall] holds the proximity lock, so the screen blanks when the
///   phone is at the ear. It follows the **call**, not the call screen — the
///   phone is still at the ear after backing out to the chat list.
/// - [setKeepScreenOn] stops the display timing out. It follows the **screen**,
///   because keeping the display awake while the user is reading messages
///   would be a battery bug, not a feature.
///
/// No-op off Android: the channel is not registered there. iOS is **not**
/// covered — it needs `UIDevice.isProximityMonitoringEnabled` set for the
/// duration of the call, which nothing does yet.
class AndroidCallScreenLock {
  const AndroidCallScreenLock._();

  static const MethodChannel _channel = MethodChannel(
    'com.ababilx.app/call_screen_lock',
  );

  static bool get _supported => !kIsWeb && Platform.isAndroid;

  static bool _earpiece = false;
  static bool _keepAwake = false;

  /// True while a call is connected **and** its audio is on the earpiece.
  /// Native drops the lock by itself if a headset appears, so this only has to
  /// track speakerphone.
  static Future<void> setEarpieceCall(bool active) async {
    if (!_supported || active == _earpiece) return;
    _earpiece = active;
    await _invoke('setEarpieceCall', {'active': active});
  }

  /// True while a call screen is on top.
  static Future<void> setKeepScreenOn(bool on) async {
    if (!_supported || on == _keepAwake) return;
    _keepAwake = on;
    await _invoke('setKeepScreenOn', {'on': on});
  }

  static Future<bool> isProximitySupported() async {
    if (!_supported) return false;
    return await _invoke('isSupported', null) == true;
  }

  static Future<Object?> _invoke(String method, Object? args) async {
    try {
      return await _channel.invokeMethod<Object?>(method, args);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      // Older host without the channel; the call runs, the screen just stays lit.
      return null;
    }
  }
}
