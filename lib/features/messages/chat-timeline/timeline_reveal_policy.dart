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

/// Whether the collapsing header should be showing, given where the list is
/// and which way it just moved.
///
/// A `reverse: true` list counts *up* into older history, so a positive delta
/// is a scroll backwards through the conversation — that hides the header, and
/// coming back down or reaching the newest messages shows it again. Small
/// jitter is ignored so the bar does not flicker under a resting thumb.
bool resolveHeaderVisibility({
  required double pixels,
  required double delta,
  required bool visible,
}) {
  if (pixels < 24) return true;
  if (delta.abs() < 8) return visible;
  return delta < 0;
}
