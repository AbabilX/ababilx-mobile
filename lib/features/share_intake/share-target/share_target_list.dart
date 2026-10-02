import 'package:flutter/material.dart';

import '../../../shared/widgets/app_avatar.dart';
import '../../messages/data/models/chat_models.dart';

/// Conversation picker for an incoming share — Signal's "Share with" list.
///
/// Multi-select on purpose: sharing the same photo to two people is the whole
/// reason someone opens the system share sheet instead of the app.
class ShareTargetList extends StatelessWidget {
  const ShareTargetList({
    super.key,
    required this.conversations,
    required this.currentUserId,
    required this.selected,
    required this.onToggle,
    required this.enabled,
  });

  final List<ChatConversation> conversations;
  final String currentUserId;
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (conversations.isEmpty) {
      return const _NoTargets();
    }
    return ListView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: conversations.length,
      itemBuilder: (_, i) {
        final c = conversations[i];
        return _TargetRow(
          conversation: c,
          title: c.displayTitle(currentUserId),
          checked: selected.contains(c.id),
          enabled: enabled,
          onTap: () => onToggle(c.id),
        );
      },
    );
  }
}

class _TargetRow extends StatelessWidget {
  const _TargetRow({
    required this.conversation,
    required this.title,
    required this.checked,
    required this.enabled,
    required this.onTap,
  });

  final ChatConversation conversation;
  final String title;
  final bool checked;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final avatarUrl = conversation.isGroupConversation
        ? null
        : conversation.peerUserAvatar;

    return InkWell(
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
        child: Row(
          children: [
            AppAvatar(
              size: 44,
              url: (avatarUrl?.isNotEmpty ?? false) ? avatarUrl : null,
              name: title,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium,
                  ),
                  Text(
                    _subtitle(conversation),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              checked ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: checked ? colors.primary : colors.outline,
            ),
          ],
        ),
      ),
    );
  }
}

String _subtitle(ChatConversation c) {
  if (c.isChannel || c.isGroup) return 'Group';
  return 'Direct message';
}

class _NoTargets extends StatelessWidget {
  const _NoTargets();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          'No conversations to share into yet. Start a chat first, then share '
          'again.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
