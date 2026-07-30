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

  /// Desired playing state. Native calls are serialized so overlapping
  /// start/stop cannot leave the tone stuck on or silently skipped.
  static bool _wantPlaying = false;
  static Future<void>? _chain;

  static Future<void> start() {
    _wantPlaying = true;
    return _enqueue();
  }

  static Future<void> stop() {
    _wantPlaying = false;
    return _enqueue();
  }

  static Future<void> _enqueue() {
    final previous = _chain;
    late final Future<void> next;
    next = () async {
      if (previous != null) {
        try {
          await previous;
        } catch (_) {}
      }
      await _applyDesired();
    }();
    _chain = next;
    return next;
  }

  static Future<void> _applyDesired() async {
    // Loop until native matches the latest desired flag (handles churn while
    // awaiting the platform channel).
    while (true) {
      final want = _wantPlaying;
      try {
        await _channel.invokeMethod<void>(want ? 'start' : 'stop');
      } catch (_) {}
      if (_wantPlaying == want) return;
    }
  }
}
