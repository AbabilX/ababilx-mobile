/// How the ringing tone is actually produced on this platform.
///
/// [CallRingtone] owns *who* wants the ring (`dm`, `group`) and serialises the
/// transitions; an engine owns only *how* it is played, because that differs
/// per platform: Android rings through a native player shared with CallKit,
/// iOS through the bundled asset.
abstract class RingtoneEngine {
  /// Begin (or keep) playing. Returns whether the tone is really running —
  /// a failed start must never be recorded as playing, or every later request
  /// is treated as a no-op and the process rings silently for good.
  Future<bool> start();

  /// Play again from the top.
  Future<bool> restart();

  Future<void> stop();

  /// Whether taking the ring back from a dismissed native ringer needs the
  /// tone replayed from position 0. False when both ringers are the same
  /// native player, since it never stopped.
  bool get replayOnHandoff;

  /// Liveness guard, applied after every state change. Engines whose player
  /// can be paused behind the app's back use it to detect and recover; the
  /// native engine has nothing to guard.
  void guard({required bool wanted, required bool playing}) {}
}
