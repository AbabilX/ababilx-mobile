import 'package:flutter/foundation.dart';

/// Where each page of scrollback came from, and how long it took.
///
/// Debug and profile builds only; release compiles it away. One line per
/// step — `[ChatOlder] <feed> store rows=50 9ms`, `server rows=50 412ms`,
/// `refresh rows=2 280ms` — so "scrolling back is slow" or "it is still
/// asking the server" can be read off a device log. A healthy scroll through
/// stored history is all `store` lines; `server` appears only at the old end
/// of what the phone has proven it holds. The feed key is cut to its first
/// eight characters, as [ChatOpenTrace] does.
class ChatOlderTrace {
  ChatOlderTrace._();

  static Stopwatch? start() => kReleaseMode ? null : (Stopwatch()..start());

  static void end(Stopwatch? clock, String key, String source, int rows) {
    if (clock == null) return;
    debugPrint(
      '[ChatOlder] ${key.length > 8 ? key.substring(0, 8) : key} '
      '$source rows=$rows ${clock.elapsedMilliseconds}ms',
    );
  }
}
