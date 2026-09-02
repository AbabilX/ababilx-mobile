import 'models/chat_message.dart';

/// One canonical timeline: last copy of an identity wins, then time and id
/// provide an ordering that never depends on API response or SQLite row order.
///
/// Identity is the non-empty `clientRef` when present, otherwise `id`. A send
/// therefore stays one row from the local bubble through the websocket confirm
/// and the HTTP response — the settled copy wins over a still-pending one.
List<ChatMessage> canonicalChatMessages(Iterable<ChatMessage> messages) {
  final byIdentity = <String, ChatMessage>{};
  for (final message in messages) {
    final identity = _messageIdentity(message);
    if (identity.isEmpty) continue;
    final existing = byIdentity[identity];
    byIdentity[identity] = existing == null
        ? message
        : _preferSettled(existing, message);
  }
  final merged = byIdentity.values.toList();
  merged.sort((left, right) {
    final byTime = _messageTime(left).compareTo(_messageTime(right));
    return byTime != 0 ? byTime : left.id.compareTo(right.id);
  });
  return merged;
}

String _messageIdentity(ChatMessage message) {
  final ref = message.clientRef;
  if (ref != null && ref.isNotEmpty) return ref;
  return message.id;
}

ChatMessage _preferSettled(ChatMessage current, ChatMessage incoming) {
  if (current.isPending != incoming.isPending) {
    return incoming.isPending ? current : incoming;
  }
  return incoming;
}

int _messageTime(ChatMessage message) =>
    DateTime.tryParse(message.createdAt)?.millisecondsSinceEpoch ?? 0;
