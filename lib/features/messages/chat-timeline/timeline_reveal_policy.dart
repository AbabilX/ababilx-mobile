import '../data/models/chat_models.dart';

/// Outgoing messages must never be hidden below the composer after send.
/// Incoming messages preserve the reader's position unless they are already
/// close to the newest edge.
bool shouldRevealNewestMessage({
  required String? previousNewestId,
  required List<ChatMessage> messages,
  required String currentUserId,
  required bool isNearBottom,
}) {
  if (messages.isEmpty) return false;
  final newest = messages.last;
  if (newest.id == previousNewestId) return false;
  return newest.userId == currentUserId || isNearBottom;
}
