import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../shared/widgets/app_avatar.dart';
import '../../calls/providers/in_call_presence_provider.dart';
import '../../calls/widgets/in_call_label.dart';
import '../../profile/providers/user_status_provider.dart';
import '../../profile/widgets/user_status_badge.dart';
import '../chat_icon.dart';
import '../chat_list_filters.dart';
import '../chat-unread-badge.dart';
import '../data/models/chat_models.dart';
import 'group_avatar_stack.dart';

class ConversationRow extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final title = conversation.displayTitle(currentUserId);
    final preview = chatListPreview(conversation, currentUserId);
    final time = relativeChatTime(conversation.lastMessageAt);
    final unread = conversation.unreadCount > 0;
    final peerInCall = conversation.isDm &&
        ref.watch(isUserInCallProvider(conversation.peerUserId));
    final peerStatus = conversation.isDm && !peerInCall
        ? ref.watch(userStatusForProvider(conversation.peerUserId))
        : null;
    final previewStyle = TextStyle(
      fontSize: 15,
      height: 1.28,
      color: colors.onSurfaceVariant,
      fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
    );

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
                      Flexible(
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
                      if (peerInCall) ...[
                        const SizedBox(width: 6),
                        const InCallLabel(compact: true),
                      ] else if (peerStatus != null) ...[
                        const SizedBox(width: 6),
                        UserStatusBadge(status: peerStatus, compact: true),
                      ],
                      if (conversation.muted)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: ChatIcon(
                            HugeIcons.strokeRoundedNotificationOff01,
                            size: 14,
                            color: colors.onSurfaceVariant,
                          ),
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
                        child: _PreviewLine(
                          preview: preview,
                          style: previewStyle,
                          youStyle: previewStyle.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colors.onSurface,
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

/// One-row message preview + file badges; scrolls horizontally when needed.
class _PreviewLine extends StatelessWidget {
  const _PreviewLine({
    required this.preview,
    required this.style,
    required this.youStyle,
  });

  final ChatListPreview preview;
  final TextStyle style;
  final TextStyle youStyle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final empty = !preview.hasText && !preview.hasFiles;

    return SizedBox(
      height: 28,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: [
          if (preview.fromMe)
            Center(
              child: Text('You: ', style: youStyle),
            ),
          if (preview.hasText)
            Center(
              child: Text(preview.text, style: style),
            )
          else if (empty)
            Center(
              child: Text('No messages yet', style: style),
            ),
          if (preview.hasFiles) ...[
            if (preview.hasText || preview.fromMe) const SizedBox(width: 8),
            for (var i = 0; i < preview.files.length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              _FileBadge(file: preview.files[i], colors: colors),
            ],
          ],
        ],
      ),
    );
  }
}

class _FileBadge extends StatelessWidget {
  const _FileBadge({required this.file, required this.colors});

  final ChatLastAttachment file;
  final ColorScheme colors;

  IconData get _icon {
    if (file.isImage) return Icons.image_outlined;
    if (file.isVideo) return Icons.videocam_outlined;
    if (file.isAudio) return Icons.graphic_eq_rounded;
    if (file.isPdf) return Icons.picture_as_pdf_outlined;
    return Icons.attach_file_rounded;
  }

  String get _label {
    final name = file.fileName.trim();
    if (name.isNotEmpty) return name;
    if (file.isImage) return 'Photo';
    if (file.isVideo) return 'Video';
    if (file.isAudio) return 'Audio';
    if (file.isPdf) return 'PDF';
    return 'File';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 140),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: 14, color: colors.onSurfaceVariant),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              _label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.onSurface,
              ),
            ),
          ),
        ],
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
