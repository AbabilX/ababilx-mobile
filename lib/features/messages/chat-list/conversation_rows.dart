import 'package:flutter/material.dart';

import '../../../core/router/shell_bottom_bar/shell_pill_metrics.dart';
import '../../local_share/data/share_thread_queries.dart';
import '../../local_share/widgets/share_chat_row.dart';
import '../data/models/chat_models.dart';
import 'chat_list_entries.dart';
import 'conversation_row.dart';

class ConversationRows extends StatelessWidget {
  const ConversationRows({
    super.key,
    required this.entries,
    required this.onTap,
    required this.onShareTap,
    required this.onShareLongPress,
    required this.onRefresh,
    required this.onLongPress,
    this.currentUserId,
    this.header,
  });

  /// A first row above the entries (the All tab's Add new friends).
  final Widget? header;

  final List<ChatListEntry> entries;
  final void Function(ChatConversation) onTap;

  /// A Local Share device thread the user moved into this list.
  final void Function(ShareThread) onShareTap;
  final void Function(ShareThread) onShareLongPress;
  final Future<void> Function() onRefresh;

  /// Signal's gesture: press and hold a row for what can be done to it.
  final void Function(ChatConversation) onLongPress;
  final String? currentUserId;

  @override
  Widget build(BuildContext context) {
    final head = header;
    if (entries.isEmpty && head == null) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          children: const [
            SizedBox(height: 120),
            Center(child: Text('No conversations')),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: EdgeInsets.only(
          bottom: ShellPillMetrics.contentBottom(context),
        ),
        itemCount: entries.length + (head == null ? 0 : 1),
        separatorBuilder: (_, _) => Divider(
          height: 1,
          indent: 82,
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
        itemBuilder: (_, index) {
          if (head != null && index == 0) return head;
          final entry = entries[head == null ? index : index - 1];
          return switch (entry) {
            ConversationEntry(conversation: final c) => ConversationRow(
              key: ValueKey(entry.key),
              conversation: c,
              currentUserId: currentUserId,
              onTap: () => onTap(c),
              onLongPress: () => onLongPress(c),
            ),
            ShareThreadEntry(:final thread) => ShareChatRow(
              key: ValueKey(entry.key),
              thread: thread,
              pinned: entry.pinned,
              onTap: () => onShareTap(thread),
              onLongPress: () => onShareLongPress(thread),
            ),
          };
        },
      ),
    );
  }
}
