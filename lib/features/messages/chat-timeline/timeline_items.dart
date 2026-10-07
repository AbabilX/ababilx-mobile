import '../chat_utils.dart';
import '../data/models/chat_message.dart';

/// One render unit in the conversation list — mirrors web
/// `chat-timeline/timeline-items.ts`. Date dividers stay attached to the
/// first unit of a day (drawn by [MessageList]), not separate items.
sealed class ChatTimelineItem {
  const ChatTimelineItem();

  /// Oldest message this unit represents — used for the date divider and
  /// unread-anchor checks.
  ChatMessage get anchor;

  String get key;
}

final class ChatTimelineMessage extends ChatTimelineItem {
  const ChatTimelineMessage(this.message);

  final ChatMessage message;

  @override
  ChatMessage get anchor => message;

  @override
  String get key => message.id;
}

/// Same-day consecutive [voice_call] / [group_call] rows (≥2) fold into one
/// disclosure. A day break or any other message type ends the run.
final class ChatTimelineCallEvents extends ChatTimelineItem {
  const ChatTimelineCallEvents(this.messages) : assert(messages.length >= 2);

  final List<ChatMessage> messages;

  @override
  ChatMessage get anchor => messages.first;

  @override
  String get key => 'call-events-${messages.first.id}';
}

/// Same-day consecutive [system] group-update rows (≥2) fold into one
/// disclosure — name/photo/member changes stacked until a real message
/// (or a day break) splits them. Mirrors [ChatTimelineCallEvents].
final class ChatTimelineGroupEvents extends ChatTimelineItem {
  const ChatTimelineGroupEvents(this.messages) : assert(messages.length >= 2);

  final List<ChatMessage> messages;

  @override
  ChatMessage get anchor => messages.first;

  @override
  String get key => 'group-events-${messages.first.id}';
}

bool isCallTimelineEvent(ChatMessage message) =>
    message.isVoiceCall || message.isGroupCall;

bool isGroupTimelineEvent(ChatMessage message) => message.isSystem;

/// Chronological [messages] (oldest → newest) → display units. Consecutive
/// same-day call events / group system events each collapse when ≥2.
List<ChatTimelineItem> buildChatTimelineItems(List<ChatMessage> messages) {
  final items = <ChatTimelineItem>[];
  var index = 0;
  while (index < messages.length) {
    final message = messages[index];
    if (isCallTimelineEvent(message)) {
      index = _appendCollapsedRun(
        items: items,
        messages: messages,
        start: index,
        matches: isCallTimelineEvent,
        fold: ChatTimelineCallEvents.new,
      );
      continue;
    }
    if (isGroupTimelineEvent(message)) {
      index = _appendCollapsedRun(
        items: items,
        messages: messages,
        start: index,
        matches: isGroupTimelineEvent,
        fold: ChatTimelineGroupEvents.new,
      );
      continue;
    }
    items.add(ChatTimelineMessage(message));
    index += 1;
  }
  return items;
}

/// Collects a same-day consecutive run starting at [start]. Returns the next
/// unread index. A lone match stays a plain [ChatTimelineMessage].
int _appendCollapsedRun({
  required List<ChatTimelineItem> items,
  required List<ChatMessage> messages,
  required int start,
  required bool Function(ChatMessage) matches,
  required ChatTimelineItem Function(List<ChatMessage>) fold,
}) {
  final run = <ChatMessage>[messages[start]];
  var lookAhead = start + 1;
  while (lookAhead < messages.length) {
    final next = messages[lookAhead];
    if (!matches(next)) break;
    if (!isSameDay(messages[lookAhead - 1].createdAt, next.createdAt)) {
      break;
    }
    run.add(next);
    lookAhead += 1;
  }
  if (run.length >= 2) {
    items.add(fold(run));
  } else {
    items.add(ChatTimelineMessage(messages[start]));
  }
  return lookAhead;
}

/// Row keys for the `reverse: true` timeline (position 0 = newest), and the
/// position each key sits at — what `findChildIndexCallback` answers.
///
/// Without them a message arriving at the bottom shifts every index by one,
/// and each built row's element — its state, its attachment lookups, its
/// locked media frame — is handed the message beside it: every visible photo
/// flashed and re-sized at once. A repeated id (canonicalisation should never
/// let one through) takes a positional suffix, so two rows never claim a key.
({List<String> keys, Map<String, int> positions}) timelineRowKeys(
  List<ChatTimelineItem> items,
) {
  final keys = List<String>.filled(items.length, '');
  final positions = <String, int>{};
  for (var i = 0; i < items.length; i++) {
    var key = items[items.length - 1 - i].key;
    if (positions.containsKey(key)) key = '$key#$i';
    positions[key] = i;
    keys[i] = key;
  }
  return (keys: keys, positions: positions);
}

bool timelineItemContains(ChatTimelineItem item, String id) {
  return switch (item) {
    ChatTimelineMessage(:final message) => message.id == id,
    ChatTimelineCallEvents(:final messages) => messages.any((m) => m.id == id),
    ChatTimelineGroupEvents(:final messages) => messages.any((m) => m.id == id),
  };
}
