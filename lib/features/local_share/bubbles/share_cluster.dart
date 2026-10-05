import '../../messages/chat_utils.dart';
import '../data/share_thread_queries.dart';

const _runGapMs = 3 * 60 * 1000;

bool _joins(ShareBubbleData? a, ShareBubbleData b) =>
    a != null &&
    a.message.fromMe == b.message.fromMe &&
    (a.message.sentAt - b.message.sentAt).abs() < _runGapMs;

/// Where a bubble sits in a run of messages from one side, which decides the
/// corner it collapses — the same rule the chat timeline uses.
MessageClusterPosition shareClusterPosition(
  ShareBubbleData? older,
  ShareBubbleData current,
  ShareBubbleData? newer,
) {
  final above = _joins(older, current);
  final below = _joins(newer, current);
  if (above && below) return MessageClusterPosition.middle;
  if (above) return MessageClusterPosition.end;
  if (below) return MessageClusterPosition.start;
  return MessageClusterPosition.single;
}
