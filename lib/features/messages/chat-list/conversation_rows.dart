import 'package:flutter/material.dart';

import '../../../core/router/shell_bottom_bar/shell_pill_metrics.dart';
import '../data/models/chat_models.dart';
import 'conversation_row.dart';

class ConversationRows extends StatelessWidget {
  const ConversationRows({
    super.key,
    required this.conversations,
    required this.onTap,
    required this.onRefresh,
    required this.onLongPress,
    this.currentUserId,
  });

  final List<ChatConversation> conversations;
  final void Function(ChatConversation) onTap;
  final Future<void> Function() onRefresh;

  /// Signal's gesture: press and hold a row for what can be done to it.
  final void Function(ChatConversation) onLongPress;
  final String? currentUserId;

  @override
  Widget build(BuildContext context) {
    if (conversations.isEmpty) {
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
        itemCount: conversations.length,
        separatorBuilder: (_, _) => Divider(
          height: 1,
          indent: 82,
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
        itemBuilder: (_, i) {
          final c = conversations[i];
          return ConversationRow(
            key: ValueKey(c.id),
            conversation: c,
            currentUserId: currentUserId,
            onTap: () => onTap(c),
            onLongPress: () => onLongPress(c),
          );
        },
      ),
    );
  }
}
