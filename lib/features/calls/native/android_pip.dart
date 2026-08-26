import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Picture-in-picture, Signal's answer to "I left the call screen".
///
/// Signal's call Activity shrinks into a floating window on back or Home
/// rather than closing, so a call is never running with nothing on screen.
/// Ours is one Activity for the whole app, so PiP is armed only while a call
/// route is showing — [setActive] is what arms it, and the native side refuses
/// to shrink when it is off.
///
/// Every method is a no-op off Android: iOS has no equivalent and the channel
/// is not registered there.
class AndroidPip {
  const AndroidPip._();

  static const MethodChannel _channel = MethodChannel('com.ababilx.app/pip');
  static const EventChannel _events = EventChannel(
    'com.ababilx.app/pip/events',
  );

  /// Whether the app is currently drawn as a floating window. Widgets watch
  /// this to swap in a layout that reads at thumbnail size.
  static final ValueNotifier<bool> inPip = ValueNotifier<bool>(false);

  static bool _listening = false;
  static bool _active = false;

  static bool get _android => !kIsWeb && Platform.isAndroid;

  /// Arm or disarm PiP. Safe to call repeatedly with the same value.
  static Future<void> setActive(bool active) async {
    if (!_android || active == _active) return;
    _active = active;
    _listen();
    await _invoke('setActive', {'active': active});
    if (!active) inPip.value = false;
  }

  /// Shrink now. Returns false when the device refuses — the caller must then
  /// fall back to leaving the call screen the ordinary way.
  static Future<bool> enter() async {
    if (!_android || !_active) return false;
    final entered = await _invoke('enter', null);
    return entered == true;
  }

  static Future<bool> isSupported() async {
    if (!_android) return false;
    return await _invoke('isSupported', null) == true;
  }

  static void _listen() {
    if (_listening || !_android) return;
    _listening = true;
    _events.receiveBroadcastStream().listen(
      (event) => inPip.value = event == true,
      onError: (_) {},
    );
  }

  static Future<Object?> _invoke(String method, Object? args) async {
    try {
      return await _channel.invokeMethod<Object?>(method, args);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
