import 'package:flutter/services.dart';

/// In-app incoming ringtone for the Flutter call screen (foreground).
///
/// Background / lock-screen ringing is handled by CallKit
/// (`ringtonePath: system_ringtone_default`). This covers the path where
/// CallStoreSync opens `/call` while the app is focused and CallKit is skipped.
///
/// Uses a platform channel (Android RingtoneManager / iOS system sound) so we
/// don't depend on `flutter_ringtone_player` (stuck on compileSdk 33).
class IncomingCallRingtone {
  IncomingCallRingtone._();

  static const _channel = MethodChannel('com.ababilx.app/ringtone');
  static bool _playing = false;

  static Future<void> start() async {
    if (_playing) return;
    _playing = true;
    try {
      await _channel.invokeMethod<void>('start');
    } catch (_) {
      _playing = false;
    }
  }

  static Future<void> stop() async {
    if (!_playing) return;
    _playing = false;
    try {
      await _channel.invokeMethod<void>('stop');
    } catch (_) {}
  }
}
