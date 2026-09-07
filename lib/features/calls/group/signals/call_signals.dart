import 'dart:convert';
import 'dart:typed_data';

/// Hands and reactions ride LiveKit's data channel, not the API: they are
/// ephemeral room chatter that no server needs to store, and adding an endpoint
/// for them would make a lost packet look like lost state.
///
/// The wire format is shared with web `reactions/call-signals.ts` — the same
/// JSON keys and the same topic. Change one side alone and a hand raised on a
/// phone is invisible in a browser, with no error anywhere.
const String callSignalTopic = 'ababilx-call';

/// Emoji offered by the reaction picker, in the same order as web.
const List<String> callReactions = [
  '❤️',
  '👍',
  '👋',
  '😂',
  '😮',
  '🎉',
  '😢',
  '🙏',
];

/// A burst is drawn for this long, then dropped from state.
const Duration reactionTtl = Duration(milliseconds: 4500);

sealed class CallSignal {
  const CallSignal();
}

class ReactionSignal extends CallSignal {
  const ReactionSignal(this.emoji);
  final String emoji;
}

class HandSignal extends CallSignal {
  const HandSignal(this.raised);
  final bool raised;
}

Uint8List encodeCallSignal(CallSignal signal) {
  final map = switch (signal) {
    ReactionSignal(:final emoji) => {'t': 'reaction', 'emoji': emoji},
    HandSignal(:final raised) => {'t': 'hand', 'raised': raised},
  };
  return Uint8List.fromList(utf8.encode(jsonEncode(map)));
}

CallSignal? decodeCallSignal(List<int> payload) {
  try {
    final parsed = jsonDecode(utf8.decode(payload));
    if (parsed is! Map) return null;
    final emoji = parsed['emoji'];
    if (parsed['t'] == 'reaction' && emoji is String) {
      return ReactionSignal(
        emoji.length > 8 ? emoji.substring(0, 8) : emoji,
      );
    }
    final raised = parsed['raised'];
    if (parsed['t'] == 'hand' && raised is bool) return HandSignal(raised);
    return null;
  } catch (_) {
    return null;
  }
}

/// Raised hands oldest-first — the queue order everyone should read.
List<String> handQueue(Map<String, DateTime> hands) {
  final entries = hands.entries.toList()
    ..sort((a, b) => a.value.compareTo(b.value));
  return entries.map((entry) => entry.key).toList();
}
