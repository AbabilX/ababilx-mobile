import 'models/chat_message.dart';

/// One canonical timeline: last copy of an identity wins, then time and id
/// provide an ordering that never depends on API response or SQLite row order.
///
/// A send can appear as a local bubble (`id == clientRef`), a websocket copy
/// that echoes `client_message_id`, and a history-page copy that only has the
/// server id. Those are one message. Live + local must never both stay.
///
/// Linear in the size of the feed: this runs on every page and every socket
/// message, over the whole open timeline. Finding "the same send" is a lookup
/// by each identity a kept message answers to, and each timestamp is parsed
/// once — comparing every pair, and re-parsing dates inside the sort, made
/// each page of scrollback slower than the one before it.
List<ChatMessage> canonicalChatMessages(Iterable<ChatMessage> messages) {
  final merged = <ChatMessage?>[];
  final places = <String, int>{};
  // A slot emptied because its row turned out to be another slot's send.
  final movedTo = <int, int>{};
  int? placeOf(String? identity) {
    if (identity == null || identity.isEmpty) return null;
    var index = places[identity];
    while (index != null && movedTo.containsKey(index)) {
      index = movedTo[index];
    }
    return index;
  }

  for (final message in messages) {
    if (message.id.isEmpty) continue;
    final byId = placeOf(message.id);
    final byRef = placeOf(message.clientRef);
    final index = byId ?? byRef;
    if (index == null) {
      merged.add(message);
      _claim(places, message, merged.length - 1);
      continue;
    }
    var kept = merged[index]!;
    if (byRef != null && byRef != index) {
      // This copy carries both the server id and the client ref, and so
      // shows two rows kept apart until now — the local bubble and a
      // history copy without a ref — to be one send.
      kept = preferCanonicalChatMessage(merged[byRef]!, kept);
      merged[byRef] = null;
      movedTo[byRef] = index;
    }
    merged[index] = preferCanonicalChatMessage(kept, message);
    // Both copies' identities keep pointing here, whichever one was kept.
    _claim(places, message, index);
  }
  final timed =
      [
        for (final m in merged)
          if (m != null) (message: m, at: _messageTime(m)),
      ]..sort((left, right) {
        final byTime = left.at.compareTo(right.at);
        return byTime != 0
            ? byTime
            : left.message.id.compareTo(right.message.id);
      });
  return [for (final entry in timed) entry.message];
}

void _claim(Map<String, int> places, ChatMessage message, int index) {
  places[message.id] = index;
  final ref = message.clientRef;
  if (ref != null && ref.isNotEmpty) places[ref] = index;
}

/// True when [a] and [b] are the same send: same server id, same client ref,
/// or a pending bubble whose row id is the other copy's client ref.
bool sameChatMessage(ChatMessage a, ChatMessage b) {
  if (a.id.isNotEmpty && a.id == b.id) return true;
  final aRef = a.clientRef;
  final bRef = b.clientRef;
  if (aRef != null && aRef.isNotEmpty) {
    if (aRef == bRef || aRef == b.id) return true;
  }
  if (bRef != null && bRef.isNotEmpty && bRef == a.id) return true;
  return false;
}

/// Settled wins over pending. A copy that still carries `clientRef` wins over
/// a history-page clone of the same server id that dropped it.
ChatMessage preferCanonicalChatMessage(
  ChatMessage current,
  ChatMessage incoming,
) {
  if (current.isPending != incoming.isPending) {
    return incoming.isPending ? current : incoming;
  }
  final currentHasRef =
      current.clientRef != null && current.clientRef!.isNotEmpty;
  final incomingHasRef =
      incoming.clientRef != null && incoming.clientRef!.isNotEmpty;
  if (incomingHasRef && !currentHasRef) return incoming;
  if (currentHasRef && !incomingHasRef) return current;
  return incoming;
}

int _messageTime(ChatMessage message) =>
    DateTime.tryParse(message.createdAt)?.millisecondsSinceEpoch ?? 0;
