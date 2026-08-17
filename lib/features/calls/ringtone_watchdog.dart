import 'dart:async';

/// Liveness guard for the in-app call ringtone.
///
/// Android pauses the underlying MediaPlayer on audio-focus loss without
/// telling Dart, so the player keeps reporting `playing` while the phone is
/// silent — that is how a ring went quiet a few seconds in and never came
/// back. Playback position is the only honest signal, so a position that stops
/// moving means play it again.
class RingtoneWatchdog {
  RingtoneWatchdog({
    required this.position,
    required this.playing,
    required this.restart,
    required this.onStall,
  });

  /// Real playback position, or null when it cannot be read.
  final Future<Duration?> Function() position;

  /// Whether a start succeeded and the tone is meant to be audible.
  final bool Function() playing;

  /// Play again from the top.
  final Future<void> Function() restart;

  /// Diagnostics for a detected stall.
  final void Function(Duration? position) onStall;

  static const _tick = Duration(seconds: 1);

  /// Two stalled reads, so a coarse position clock is never mistaken for
  /// silence. Worst-case recovery is therefore ~2s.
  static const _stallsBeforeRestart = 2;

  Timer? _timer;
  Duration? _last;
  int _stalls = 0;
  bool _checking = false;

  void start() {
    _timer ??= Timer.periodic(_tick, (_) => unawaited(_check()));
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    reset();
  }

  /// Forget the last reading — call after a fresh start so the next tick
  /// compares against this playback, not the one before it.
  void reset() {
    _last = null;
    _stalls = 0;
  }

  Future<void> _check() async {
    if (_checking) return;
    _checking = true;
    try {
      if (!playing()) {
        // A start that failed outright; keep retrying while a holder waits.
        await restart();
        return;
      }
      Duration? current;
      try {
        current = await position();
      } catch (_) {
        current = null;
      }
      final moved = current != null && current != _last;
      _last = current;
      if (moved) {
        _stalls = 0;
        return;
      }
      if (++_stalls < _stallsBeforeRestart) return;
      _stalls = 0;
      onStall(current);
      await restart();
    } finally {
      _checking = false;
    }
  }
}
