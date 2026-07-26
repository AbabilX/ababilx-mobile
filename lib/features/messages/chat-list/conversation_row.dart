import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../shared/widgets/app_avatar.dart';
import '../chat_icon.dart';
import '../chat_list_filters.dart';
import '../chat-unread-badge.dart';
import '../data/models/chat_models.dart';
import 'group_avatar_stack.dart';

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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ConversationAvatar(conversation: conversation, title: title),
            const SizedBox(width: 14),
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
                            fontSize: 16,
                            fontWeight: unread
                                ? FontWeight.w800
                                : FontWeight.w600,
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
                            fontWeight: FontWeight.w500,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          preview,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.28,
                            color: colors.onSurfaceVariant,
                            fontWeight: unread
                                ? FontWeight.w600
                                : FontWeight.w400,
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

class _ConversationAvatar extends StatelessWidget {
  const _ConversationAvatar({required this.conversation, required this.title});

  final ChatConversation conversation;
  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (conversation.isChannel) {
      return GroupAvatarStack(
        avatars: conversation.memberAvatars,
        name: title,
        size: 52,
      );
    }
    return AppAvatar(
      size: 52,
      url: conversation.peerUserAvatar,
      name: title,
      fallback: ChatIcon(
        HugeIcons.strokeRoundedUser02,
        color: colors.onSurfaceVariant,
      ),
    );
  }
}
