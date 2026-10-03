import 'dart:async';

/// Asks again, a bounded number of times, after a call lookup failed for a
/// reason that says nothing about the call.
///
/// Bounded on purpose: the ring has its own clock (the CallKit surface times
/// out by itself, the server sweeps the row), and every app resume or socket
/// reconnect is another chance. This only covers the seconds in between, so a
/// radio that needed two seconds to wake does not cost the user the call.
class CallLookupRetry {
  CallLookupRetry({this.delays = defaultDelays});

  static const defaultDelays = [
    Duration(seconds: 2),
    Duration(seconds: 4),
    Duration(seconds: 8),
    Duration(seconds: 16),
  ];

  final List<Duration> delays;

  Timer? _timer;
  String? _callId;
  int _attempts = 0;

  /// Schedules [retry] for [callId]. Returns false, scheduling nothing, once
  /// that call's budget is spent — [limit] attempts, or all of [delays].
  bool schedule(String callId, void Function() retry, {int? limit}) {
    if (_callId != callId) {
      _callId = callId;
      _attempts = 0;
    }
    final budget = limit == null || limit > delays.length
        ? delays.length
        : limit;
    if (_attempts >= budget) return false;
    _timer?.cancel();
    final delay = delays[_attempts];
    _attempts++;
    _timer = Timer(delay, () {
      _timer = null;
      retry();
    });
    return true;
  }

  /// The lookup for [callId] was answered: a later failure starts afresh.
  void settle(String callId) {
    if (_callId == callId) cancel();
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
    _callId = null;
    _attempts = 0;
  }
}
