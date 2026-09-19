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

bool isCallTimelineEvent(ChatMessage message) =>
    message.isVoiceCall || message.isGroupCall;

/// Chronological [messages] (oldest → newest) → display units. Consecutive
/// same-day call events collapse when there are at least two.
List<ChatTimelineItem> buildChatTimelineItems(List<ChatMessage> messages) {
  final items = <ChatTimelineItem>[];
  var index = 0;
  while (index < messages.length) {
    final message = messages[index];
    if (!isCallTimelineEvent(message)) {
      items.add(ChatTimelineMessage(message));
      index += 1;
      continue;
    }
    final run = <ChatMessage>[message];
    var lookAhead = index + 1;
    while (lookAhead < messages.length) {
      final next = messages[lookAhead];
      if (!isCallTimelineEvent(next)) break;
      if (!isSameDay(messages[lookAhead - 1].createdAt, next.createdAt)) {
        break;
      }
      run.add(next);
      lookAhead += 1;
    }
    if (run.length >= 2) {
      items.add(ChatTimelineCallEvents(run));
    } else {
      items.add(ChatTimelineMessage(message));
    }
    index = lookAhead;
  }
  return items;
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
