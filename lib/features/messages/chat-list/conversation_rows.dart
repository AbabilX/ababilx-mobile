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
    this.currentUserId,
  });

  final List<ChatConversation> conversations;
  final void Function(ChatConversation) onTap;
  final Future<void> Function() onRefresh;
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
        padding: const EdgeInsets.only(
          bottom: ShellPillMetrics.contentBottomInset,
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
            conversation: c,
            currentUserId: currentUserId,
            onTap: () => onTap(c),
          );
        },
      ),
    );
  }
}
