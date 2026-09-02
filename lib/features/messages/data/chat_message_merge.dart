import 'models/chat_message.dart';

/// One canonical timeline: last copy of an identity wins, then time and id
/// provide an ordering that never depends on API response or SQLite row order.
///
/// A send can appear as a local bubble (`id == clientRef`), a websocket copy
/// that echoes `client_message_id`, and a history-page copy that only has the
/// server id. Those are one message. Live + local must never both stay.
List<ChatMessage> canonicalChatMessages(Iterable<ChatMessage> messages) {
  final merged = <ChatMessage>[];
  for (final message in messages) {
    if (message.id.isEmpty) continue;
    final index = merged.indexWhere(
      (existing) => sameChatMessage(existing, message),
    );
    if (index < 0) {
      merged.add(message);
      continue;
    }
    merged[index] = preferCanonicalChatMessage(merged[index], message);
  }
  merged.sort((left, right) {
    final byTime = _messageTime(left).compareTo(_messageTime(right));
    return byTime != 0 ? byTime : left.id.compareTo(right.id);
  });
  return merged;
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
