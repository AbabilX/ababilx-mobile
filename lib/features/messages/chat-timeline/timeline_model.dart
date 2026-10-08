import '../data/models/chat_models.dart';
import 'quote_chain.dart';
import 'timeline_items.dart';

/// Everything the message list derives from the messages before it can draw
/// a row: the grouped items, each message's place, the row keys and which
/// messages are quoted.
///
/// All four walk the whole feed, and the list rebuilds for reasons that have
/// nothing to do with the messages — the header sliding away, the jump
/// button appearing, a selection changing. Worked out once per list instance
/// and remembered against it, those rebuilds cost a lookup; a feed is never
/// changed in place, so the same instance always means the same messages.
class TimelineModel {
  TimelineModel._(this.items, this.idIndex, this.rows, this.quotedIds);

  final List<ChatTimelineItem> items;
  final Map<String, int> idIndex;
  final ({List<String> keys, Map<String, int> positions}) rows;
  final Set<String> quotedIds;

  static final _byList = Expando<TimelineModel>('timeline model');

  static TimelineModel of(List<ChatMessage> messages) =>
      _byList[messages] ??= _build(messages);

  static TimelineModel _build(List<ChatMessage> messages) {
    final items = buildChatTimelineItems(messages);
    return TimelineModel._(
      items,
      {for (var i = 0; i < messages.length; i++) messages[i].id: i},
      timelineRowKeys(items),
      quotedMessageIds(messages),
    );
  }
}
