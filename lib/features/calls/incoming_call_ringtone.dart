import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';

/// In-app incoming ringtone for the Flutter call screen (foreground).
///
/// Background / lock-screen ringing is handled by CallKit
/// (`ringtonePath: system_ringtone_default`). This covers the path where
/// CallStoreSync opens `/call` while the app is focused and CallKit is skipped.
class IncomingCallRingtone {
  IncomingCallRingtone._();

  static final _player = FlutterRingtonePlayer();
  static bool _playing = false;

  static Future<void> start() async {
    if (_playing) return;
    _playing = true;
    try {
      // System phone ringtone, loop until accept/decline/end.
      await _player.playRingtone(looping: true, volume: 1.0, asAlarm: true);
    } catch (_) {
      _playing = false;
    }
  }

  static Future<void> stop() async {
    if (!_playing) return;
    _playing = false;
    try {
      await _player.stop();
    } catch (_) {}
  }
}
