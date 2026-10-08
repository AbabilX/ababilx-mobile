import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'feed_spans.dart';

/// Where each conversation's [FeedSpans] live between launches.
///
/// Device-local, like the message store they describe, and they must leave
/// with it: a span that outlives the rows it vouches for would call an empty
/// store complete. So deleting a chat forgets its spans and wiping the
/// archive forgets them all — see `wipeConversationLocally` and
/// `ChatArchiveWiper`. Losing a span is always safe: the stretch is simply
/// walked again from the server.
class FeedSpanStore {
  static const prefix = 'chat_feed_spans_v1:';

  final _memory = <String, FeedSpans>{};

  /// Changes run one after another per conversation: two pages landing at
  /// once must not each write over the other's stretch.
  final _queue = <String, Future<void>>{};

  /// Bumped by [clearAll], so a change queued before a wipe cannot write a
  /// stretch back for rows that are gone.
  var _generation = 0;

  Future<FeedSpans> read(String conversationId) async {
    final held = _memory[conversationId];
    if (held != null) return held;
    final prefs = await SharedPreferences.getInstance();
    // A change may have landed while the preferences were being opened.
    return _memory[conversationId] ??= FeedSpans.decode(
      prefs.getString('$prefix$conversationId'),
    );
  }

  Future<FeedSpans> update(
    String conversationId,
    FeedSpans Function(FeedSpans current) change,
  ) {
    final generation = _generation;
    final done = (_queue[conversationId] ?? Future<void>.value()).then((
      _,
    ) async {
      if (generation != _generation) return const FeedSpans();
      final next = change(await read(conversationId));
      if (generation != _generation) return const FeedSpans();
      _memory[conversationId] = next;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('$prefix$conversationId', next.encode());
      } catch (_) {
        // Memory still holds it for this session; the next launch walks
        // the stretch again, which is only slower.
      }
      return next;
    });
    _queue[conversationId] = done.then<void>((_) {}, onError: (_) {});
    return done;
  }

  Future<void> forget(String conversationId) async {
    await update(conversationId, (_) => const FeedSpans());
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$prefix$conversationId');
    } catch (_) {}
  }

  Future<void> clearAll() async {
    _generation++;
    _memory.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith(prefix)).toList();
      for (final key in keys) {
        await prefs.remove(key);
      }
    } catch (_) {}
  }
}

final feedSpanStoreProvider = Provider<FeedSpanStore>((ref) => FeedSpanStore());
