/// Timing rules for recovering a call whose media path dropped.
///
/// Pure data — no timers, no I/O — so the schedule can be reasoned about and
/// unit-tested without a live call.
class VoiceReconnectPolicy {
  const VoiceReconnectPolicy({
    this.settleDelay = const Duration(seconds: 2),
    this.giveUpAfter = const Duration(seconds: 120),
    this.backoff = const [
      Duration.zero,
      Duration(seconds: 2),
      Duration(seconds: 3),
      Duration(seconds: 5),
      Duration(seconds: 8),
    ],
  });

  /// Grace before the *first* restart after a plain `disconnected`. Most such
  /// blips — a lift, a tower handover, a momentary packet gap — heal on their
  /// own inside this window, and restarting through one throws away a working
  /// candidate pair for nothing. A hard `failed`, or a network interface
  /// change, skips this: those never heal by waiting.
  final Duration settleDelay;

  /// How long a call may stay unhealthy before it is declared dead. Generous
  /// on purpose: dropping a call the network would have returned in 40s is the
  /// failure users actually complain about.
  final Duration giveUpAfter;

  /// Delay before each successive restart attempt. Short, because nothing says
  /// when coverage returned without an interface change: measured on a phone, a
  /// table reaching 20 s left voice silent 11.9 s after a 45 s outage had ended.
  /// Not shorter than this, or a restart still working over a slow link is
  /// thrown away by the next one.
  final List<Duration> backoff;

  /// Delay before attempt [attempt] (0-based). Past the table the final entry
  /// repeats — [giveUpAfter] ends the sequence, not the table's length.
  Duration delayFor(int attempt) {
    if (attempt < 0) return Duration.zero;
    return attempt < backoff.length ? backoff[attempt] : backoff.last;
  }

  bool exhausted(Duration unhealthyFor) => unhealthyFor >= giveUpAfter;
}
