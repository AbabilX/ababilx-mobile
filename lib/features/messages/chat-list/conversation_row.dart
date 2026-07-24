import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../chat_icon.dart';
import '../chat_list_filters.dart';
import '../chat-unread-badge.dart';
import '../data/models/chat_models.dart';

class ConversationRow extends StatelessWidget {
  const ConversationRow({
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
    final preview = previewWithYou(conversation, currentUserId);
    final time = relativeChatTime(conversation.lastMessageAt);
    final unread = conversation.unreadCount > 0;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SquareAvatar(conversation: conversation, title: title),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight:
                                unread ? FontWeight.w800 : FontWeight.w600,
                          ),
                        ),
                      ),
                      if (conversation.muted)
                        ChatIcon(
                          HugeIcons.strokeRoundedNotificationOff01,
                          size: 14,
                          color: colors.onSurfaceVariant,
                        ),
                      if (time.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text(
                          time,
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontWeight:
                                unread ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ),
                      ChatUnreadBadge(count: conversation.unreadCount),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SquareAvatar extends StatelessWidget {
  const _SquareAvatar({required this.conversation, required this.title});
  final ChatConversation conversation;
  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final url = conversation.isDm
        ? conversation.peerUserAvatar
        : (conversation.memberAvatars.isNotEmpty
            ? conversation.memberAvatars.first
            : null);
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 48,
        height: 48,
        child: url != null
            ? CachedNetworkImage(imageUrl: url, fit: BoxFit.cover)
            : ColoredBox(
                color: colors.surfaceContainerHighest,
                child: Center(
                  child: ChatIcon(
                    conversation.isChannel
                        ? HugeIcons.strokeRoundedTag01
                        : HugeIcons.strokeRoundedUser02,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
      ),
    );
  }
}
