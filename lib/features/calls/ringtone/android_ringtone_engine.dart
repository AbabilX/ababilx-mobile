import 'package:call_ringer/call_ringer.dart';

import 'ring_holders.dart';
import 'ringtone_engine.dart';

/// Android ring: one native `MediaPlayer` (`call_ringer`) shared with the
/// CallKit path.
///
/// Nothing about the tone lives in Dart any more. The CallKit plugin's own
/// ringer is handed a silent file because it stops itself on
/// `ACTION_SCREEN_OFF` and on any volume-change broadcast, and the previous
/// `audioplayers` tone was paused behind Dart's back on audio-focus loss. The
/// native player requests no focus, ignores screen state, and is held by both
/// `native` (CallKit) and `flutter` (this engine), so a hand-off between the
/// two ringing surfaces never interrupts the sound.
class AndroidRingtoneEngine implements RingtoneEngine {
  @override
  bool get replayOnHandoff => false;

  @override
  Future<bool> start() async {
    await CallRinger.hold(callRingHolderFlutter);
    return true;
  }

  @override
  Future<bool> restart() async {
    await CallRinger.restart(callRingHolderFlutter);
    return true;
  }

  @override
  Future<void> stop() => CallRinger.release(callRingHolderFlutter);

  @override
  void guard({required bool wanted, required bool playing}) {
    // The native player cannot be paused without us asking, and it enforces
    // its own ring-window timeout, so there is nothing to watchdog here.
  }
}
