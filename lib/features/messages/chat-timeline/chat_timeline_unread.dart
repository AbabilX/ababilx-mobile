import '../data/models/chat_models.dart';
import 'chat_timeline_load.dart';

/// The "N unread messages" bar: how many, and which message it sits above.
///
/// The conversation carries a count and no last-read timestamp, so the bar is
/// placed by counting back that many messages the first time the feed arrives,
/// then pinned to that message's id. Recounting the offset on every build made
/// it slide: every later message — the reader's own replies included — pushed
/// it one row down, so it came to rest under messages that had never been
/// unread.
mixin ChatTimelineUnread on ChatTimelineLoad {
  /// Unread count as the chat opened, before [loadFeed] marked it read.
  int unreadCount = 0;

  /// Same number on the jump-to-bottom pill, dropped once it has been used.
  int unreadPillCount = 0;

  /// Message the bar sits above. Null once there is nothing left to mark.
  String? unreadAnchorId;

  bool _anchorPinned = false;

  /// Chat opened, or switched to another conversation.
  void resetUnreadAnchor() {
    unreadCount = unreadPillCount = currentUnread();
    unreadAnchorId = null;
    _anchorPinned = false;
  }

  /// Pins the bar the first time the feed has messages; no-op after that, so
  /// loading older history or receiving new messages cannot move it.
  void pinUnreadAnchor(List<ChatMessage> messages) {
    if (_anchorPinned || messages.isEmpty) return;
    _anchorPinned = true;
    unreadAnchorId = unreadDividerAnchorId(
      unreadCount: unreadCount,
      messages: messages,
    );
  }

  /// Replying answers the unread messages, so the bar goes. Leaving it up
  /// would strand it above the reader's own reply, which reads as a lie.
  void clearUnreadAnchor() {
    if (unreadAnchorId == null && unreadPillCount == 0) return;
    setState(() {
      unreadAnchorId = null;
      unreadPillCount = 0;
    });
  }

  /// Jumping down answers the count, so the pill stops carrying it — the bar
  /// itself stays where it is until the chat is reopened.
  void clearUnreadPill() {
    if (unreadPillCount == 0) return;
    setState(() => unreadPillCount = 0);
  }
}

/// Id of the oldest unread message, or null when there is no bar to draw.
///
/// A count covering the whole loaded feed gets no bar: it would sit at the
/// very top with nothing above it to separate.
String? unreadDividerAnchorId({
  required int unreadCount,
  required List<ChatMessage> messages,
}) {
  if (unreadCount <= 0 || unreadCount >= messages.length) return null;
  return messages[messages.length - unreadCount].id;
}
