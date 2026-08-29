import 'models/chat_message.dart';

/// One canonical timeline: last copy of an id wins, then time and id provide
/// an ordering that never depends on API response or SQLite row order.
List<ChatMessage> canonicalChatMessages(Iterable<ChatMessage> messages) {
  final byId = <String, ChatMessage>{};
  for (final message in messages) {
    if (message.id.isNotEmpty) byId[message.id] = message;
  }
  final merged = byId.values.toList();
  merged.sort((left, right) {
    final byTime = _messageTime(left).compareTo(_messageTime(right));
    return byTime != 0 ? byTime : left.id.compareTo(right.id);
  });
  return merged;
}

int _messageTime(ChatMessage message) =>
    DateTime.tryParse(message.createdAt)?.millisecondsSinceEpoch ?? 0;
