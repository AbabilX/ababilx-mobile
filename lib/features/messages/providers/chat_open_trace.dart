import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Timing for one chat open: route → disk read → decrypt → first paint.
///
/// Debug and profile builds only; release compiles it away. Each open logs one
/// line, `[ChatOpen] <feed> disk=… decrypt=… paint=… rows=…`, and the same
/// phases appear as Timeline events in DevTools, so a slow open says which
/// phase it was without a debugger attached. The feed key is cut to its first
/// eight characters: enough to tell two opens apart, not an identifier worth
/// shipping to a log.
class ChatOpenTrace {
  ChatOpenTrace._();

  static final _open = <String, _Trace>{};

  static bool get _enabled => !kReleaseMode;

  static void start(String key) {
    if (!_enabled) return;
    _open[key] = _Trace();
  }

  static void mark(String key, String phase) {
    if (!_enabled) return;
    _open[key]?.mark(phase);
  }

  /// The feed is in memory with [rows] rows; the next frame is its first
  /// paint, and ends the trace.
  static void painted(String key, int rows) {
    if (!_enabled) return;
    final trace = _open.remove(key);
    if (trace == null) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      trace.mark('paint');
      debugPrint(
        '[ChatOpen] ${key.length > 8 ? key.substring(0, 8) : key} '
        '${trace.summary()} rows=$rows',
      );
    });
  }
}

class _Trace {
  final _clock = Stopwatch()..start();
  final _phases = <String, int>{};
  var _last = 0;

  void mark(String phase) {
    final now = _clock.elapsedMilliseconds;
    _phases[phase] = now - _last;
    developer.Timeline.instantSync('chat_open.$phase');
    _last = now;
  }

  String summary() => [
    for (final entry in _phases.entries) '${entry.key}=${entry.value}ms',
    'total=${_clock.elapsedMilliseconds}ms',
  ].join(' ');
}
