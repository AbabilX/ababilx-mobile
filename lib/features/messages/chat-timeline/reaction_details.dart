import '../data/models/chat_models.dart';
import '../providers/chat_state.dart';

/// One tab in the reaction sheet. [emoji] is null on the All tab.
class ReactionDetailTab {
  const ReactionDetailTab({this.emoji, required this.count});

  final String? emoji;
  final int count;

  bool get isAll => emoji == null;
}

/// One person on a tab. [emoji] is set on All so the trailing glyph can show.
class ReactionDetailRow {
  const ReactionDetailRow({
    required this.userId,
    required this.name,
    this.avatarUrl,
    required this.emoji,
  });

  final String userId;
  final String name;
  final String? avatarUrl;
  final String emoji;
}

/// All (when there is more than one emoji) plus one tab per emoji.
List<ReactionDetailTab> buildReactionDetailTabs(
  List<ChatReactionGroup> groups,
) {
  if (groups.isEmpty) return const [];
  final tabs = [
    for (final g in groups)
      if (g.emoji.isNotEmpty) ReactionDetailTab(emoji: g.emoji, count: g.count),
  ];
  if (tabs.length <= 1) return tabs;
  final total = tabs.fold<int>(0, (sum, t) => sum + t.count);
  return [ReactionDetailTab(count: total), ...tabs];
}

int reactionDetailsInitialTab({
  required List<ReactionDetailTab> tabs,
  String? initialEmoji,
}) {
  if (tabs.isEmpty) return 0;
  final emoji = initialEmoji?.trim() ?? '';
  if (emoji.isEmpty) return 0;
  final i = tabs.indexWhere((t) => t.emoji == emoji);
  return i < 0 ? 0 : i;
}

List<ReactionDetailRow> reactionDetailRows({
  required List<ChatReactionGroup> groups,
  required ReactionDetailTab tab,
}) {
  final wanted = tab.emoji;
  final rows = <ReactionDetailRow>[];
  for (final g in groups) {
    if (wanted != null && g.emoji != wanted) continue;
    for (final u in g.users) {
      if (u.userId.isEmpty) continue;
      rows.add(
        ReactionDetailRow(
          userId: u.userId,
          name: (u.name ?? '').trim(),
          avatarUrl: u.avatarUrl,
          emoji: g.emoji,
        ),
      );
    }
  }
  return rows;
}

ChatMessage? findChatMessage(ChatState chat, String messageId) {
  if (messageId.isEmpty) return null;
  for (final feed in chat.feeds.values) {
    for (final m in feed.messages) {
      if (m.id == messageId) return m;
    }
  }
  for (final replies in chat.threadRepliesByRoot.values) {
    for (final m in replies) {
      if (m.id == messageId) return m;
    }
  }
  return null;
}
