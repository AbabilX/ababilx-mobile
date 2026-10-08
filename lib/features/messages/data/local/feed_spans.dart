import 'dart:convert';

import '../models/chat_message.dart';
import 'chat_message_row.dart';

/// One stretch of a conversation's main timeline this phone is known to hold
/// in full: every message the server had, created between [lowMs] and
/// [highMs], was stored here when the stretch was fetched.
///
/// The local store alone cannot say that. Rows reach it one at a time from
/// the socket and a page at a time from the server, so two neighbours on
/// disk may have a hundred messages missing between them — everything that
/// arrived while the phone was away. A span is the proof that there is no
/// such hole, and it is what lets scrollback read the disk instead of asking
/// the server for what the phone already has.
class FeedSpan {
  const FeedSpan({
    required this.lowMs,
    required this.highMs,
    this.cursor = '',
    this.done = false,
  });

  final int lowMs;
  final int highMs;

  /// The server's own cursor at the old end: asking for the page after it
  /// continues the walk this span came from. Empty once [done].
  final String cursor;

  /// The server had nothing older when it was last asked. Whatever the phone
  /// holds below [lowMs] is then the only copy there is.
  final bool done;

  bool covers(int ms) => ms >= lowMs && ms <= highMs;

  bool _touches(FeedSpan other) =>
      lowMs <= other.highMs && other.lowMs <= highMs;

  /// The two as one stretch. The old end comes from whichever reaches
  /// further back; on a tie [this] wins, being the newer knowledge.
  FeedSpan _join(FeedSpan other) {
    final deeper = other.lowMs < lowMs ? other : this;
    return FeedSpan(
      lowMs: deeper.lowMs,
      highMs: highMs > other.highMs ? highMs : other.highMs,
      cursor: deeper.cursor,
      done: deeper.done,
    );
  }

  Map<String, dynamic> toJson() => {
    'l': lowMs,
    'h': highMs,
    if (cursor.isNotEmpty) 'c': cursor,
    if (done) 'd': true,
  };

  static FeedSpan? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final low = raw['l'];
    final high = raw['h'];
    if (low is! int || high is! int || low > high) return null;
    return FeedSpan(
      lowMs: low,
      highMs: high,
      cursor: raw['c'] is String ? raw['c'] as String : '',
      done: raw['d'] == true,
    );
  }
}

/// What a server page proves about the local store once it is saved.
///
/// The server lists the main timeline by LAST ACTIVITY, not by creation: a
/// message with thread replies sits where its newest reply is. So a page's
/// oldest row by `created_at` may be a bumped thread root from months ago,
/// and claiming everything down to it would be false. A message without
/// replies is where it was created, so the oldest of THOSE is as far back as
/// the page can vouch for. [highMs] is where the page was asked from.
FeedSpan spanOfPage(ChatMessagesPage page, {required int highMs}) {
  if (!page.hasMore) return FeedSpan(lowMs: 0, highMs: highMs, done: true);
  var low = highMs;
  for (final message in page.messages) {
    if (message.threadCount > 0) continue;
    final ms = messageTimeMs(message);
    if (ms > 0 && ms < low) low = ms;
  }
  return FeedSpan(lowMs: low, highMs: highMs, cursor: page.nextCursor);
}

/// Every proven stretch of one conversation, newest first, never touching.
class FeedSpans {
  const FeedSpans([this.spans = const []]);

  final List<FeedSpan> spans;

  /// Older stretches beyond this are forgotten. Forgetting one only costs a
  /// walk through it again; it can never show a hole.
  static const maxSpans = 8;

  bool get isEmpty => spans.isEmpty;

  /// The stretch [ms] lies in, or null when nothing vouches for that point.
  FeedSpan? at(int ms) {
    for (final span in spans) {
      if (span.covers(ms)) return span;
    }
    return null;
  }

  /// With [incoming] recorded, joined to every stretch it reaches.
  FeedSpans add(FeedSpan incoming) {
    var joined = incoming;
    final apart = <FeedSpan>[];
    for (final span in spans) {
      if (joined._touches(span)) {
        joined = joined._join(span);
      } else {
        apart.add(span);
      }
    }
    final next = [...apart, joined]
      ..sort((a, b) => b.highMs.compareTo(a.highMs));
    return FeedSpans(next.take(maxSpans).toList());
  }

  /// Stops vouching for anything older than [ms] — the store turned out not
  /// to hold what a stretch promised. The stretch around [ms] now ends
  /// there, to be walked again from [cursor].
  FeedSpans distrustBelow(int ms, {required String cursor}) {
    final kept = <FeedSpan>[];
    for (final span in spans) {
      if (span.highMs < ms) continue;
      kept.add(
        span.lowMs < ms
            ? FeedSpan(lowMs: ms, highMs: span.highMs, cursor: cursor)
            : span,
      );
    }
    return FeedSpans(kept);
  }

  String encode() => jsonEncode([for (final span in spans) span.toJson()]);

  static FeedSpans decode(String? raw) {
    if (raw == null || raw.isEmpty) return const FeedSpans();
    try {
      var out = const FeedSpans();
      for (final item in jsonDecode(raw) as List) {
        final span = FeedSpan.fromJson(item);
        if (span != null) out = out.add(span);
      }
      return out;
    } catch (_) {
      return const FeedSpans();
    }
  }
}
