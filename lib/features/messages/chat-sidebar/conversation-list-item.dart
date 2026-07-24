import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../data/models/chat_models.dart';
import '../chat_utils.dart';
import '../chat-unread-badge.dart';

class ConversationListItem extends StatelessWidget {
  const ConversationListItem({
    super.key,
    required this.conversation,
    required this.onTap,
    this.currentUserId,
  });

  final ChatConversation conversation;
  final VoidCallback onTap;
  final String? currentUserId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final title = conversation.displayTitle(currentUserId);
    final preview = conversationPreview(conversation);
    final time = formatChatTime(conversation.lastMessageAt);

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: _Avatar(conversation: conversation),
      title: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: conversation.unreadCount > 0
                    ? FontWeight.w800
                    : FontWeight.w600,
              ),
            ),
          ),
          if (conversation.muted)
            Icon(Icons.notifications_off_outlined,
                size: 14, color: colors.onSurfaceVariant),
          if (time.isNotEmpty) ...[
            const SizedBox(width: 6),
            Text(time, style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant)),
          ],
        ],
      ),
      subtitle: Text(
        preview,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: colors.onSurfaceVariant,
          fontWeight:
              conversation.unreadCount > 0 ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      trailing: ChatUnreadBadge(count: conversation.unreadCount),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.conversation});
  final ChatConversation conversation;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (conversation.isDm && conversation.peerUserAvatar != null) {
      return CircleAvatar(
        backgroundImage:
            CachedNetworkImageProvider(conversation.peerUserAvatar!),
      );
    }
    if (conversation.isChannel) {
      return CircleAvatar(
        backgroundColor: colors.surfaceContainerHigh,
        child: Icon(
          conversation.isPrivate ? Icons.lock_outline : Icons.tag,
          size: 20,
          color: colors.primary,
        ),
      );
    }
    return CircleAvatar(
      backgroundColor: colors.surfaceContainerHigh,
      child: Text(
        (conversation.peerUserName ?? '?').substring(0, 1).toUpperCase(),
        style: TextStyle(color: colors.primary, fontWeight: FontWeight.w700),
      ),
    );
  }
}
