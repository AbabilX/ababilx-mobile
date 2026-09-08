import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../shared/widgets/app_avatar.dart';
import '../../calls/providers/in_call_presence_provider.dart';
import '../../calls/widgets/in_call_label.dart';
import '../../local_share/providers/local_share_providers.dart';
import '../../profile/providers/user_status_provider.dart';
import '../../profile/widgets/user_status_badge.dart';
import '../chat_icon.dart';
import '../chat_list_filters.dart';
import '../chat_unread_badge.dart';
import '../data/models/chat_models.dart';
import '../note_to_self_avatar.dart';
import 'group_avatar_stack.dart';
import '../nickname/contact_nickname_provider.dart';
import '../nickname/nickname_title.dart';

class ConversationRow extends ConsumerWidget {
  const ConversationRow({
    super.key,
    required this.conversation,
    required this.onTap,
    this.onLongPress,
    this.currentUserId,
  });

  final ChatConversation conversation;
  final VoidCallback onTap;

  /// Signal's gesture: press and hold a row for what can be done to it.
  final VoidCallback? onLongPress;
  final String? currentUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final title = ref
        .watch(contactNicknamesProvider)
        .titleFor(conversation, currentUserId);
    final preview = chatListPreview(conversation, currentUserId);
    final time = relativeChatTime(conversation.lastMessageAt);
    final unread = conversation.unreadCount > 0;
    final peerInCall =
        conversation.hasDmPeer &&
        ref.watch(isUserInCallProvider(conversation.peerUserId));
    final peerStatus = conversation.hasDmPeer && !peerInCall
        ? ref.watch(userStatusForProvider(conversation.peerUserId))
        : null;

    // Show local share icon when peer device is detected on same Wi-Fi network.
    // Matching is done by comparing the peer's display name against each
    // discovered device's alias broadcast via UDP Multicast (LocalSend v2.1).
    final isLocalPeerNearby =
        conversation.hasDmPeer &&
        conversation.peerUserName != null &&
        ref
            .watch(nearbyDevicesProvider)
            .values
            .any((d) => d.alias.contains(conversation.peerUserName!));

    final previewStyle = TextStyle(
      fontSize: 15,
      height: 1.28,
      color: colors.onSurfaceVariant,
      fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
    );

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
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
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Left: name + inline status badges + mute icon
                      Expanded(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
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
                              UserStatusBadge(
                                status: peerStatus,
                                compact: true,
                              ),
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
                          ],
                        ),
                      ),
                      // Right: local-share indicator + timestamp, always at edge
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isLocalPeerNearby) ...[
                            const SizedBox(width: 4),
                            ChatIcon(
                              HugeIcons.strokeRoundedFolderTransfer,
                              size: 15,
                              color: colors.primary,
                            ),
                          ],
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
                          currentUserId: currentUserId,
                        ),
                      ),
                      // Signal puts the pin where the unread badge goes and
                      // lets the badge win: a pinned chat with something to
                      // read has more to say about the badge than the pin.
                      if (conversation.pinned && conversation.unreadCount <= 0)
                        ChatIcon(
                          HugeIcons.strokeRoundedPin,
                          size: 15,
                          color: colors.onSurfaceVariant,
                        )
                      else
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

/// Two-line message preview + file badges with rich URLs and mention badges.
class _PreviewLine extends StatelessWidget {
  const _PreviewLine({
    required this.preview,
    required this.style,
    required this.youStyle,
    this.currentUserId,
  });

  final ChatListPreview preview;
  final TextStyle style;
  final TextStyle youStyle;
  final String? currentUserId;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final empty = !preview.hasText && !preview.hasFiles;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: _buildSpans(
              text: preview.text,
              style: style,
              youStyle: youStyle,
              colors: colors,
              fromMe: preview.fromMe && (preview.hasText || preview.hasFiles),
              empty: empty,
            ),
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (preview.hasFiles) ...[
          const SizedBox(height: 4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < preview.files.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  _FileBadge(file: preview.files[i], colors: colors),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  List<InlineSpan> _buildSpans({
    required String text,
    required TextStyle style,
    required TextStyle youStyle,
    required ColorScheme colors,
    required bool fromMe,
    required bool empty,
  }) {
    final spans = <InlineSpan>[];

    if (fromMe) {
      spans.add(TextSpan(text: 'You: ', style: youStyle));
    }

    if (empty) {
      spans.add(TextSpan(text: 'No messages yet', style: style));
      return spans;
    }

    // Pattern to match URLs (http:// or https://) or @mentions
    final pattern = RegExp(
      r'(https?://[^\s]+|@[A-Za-z0-9_\-\u0980-\u09FF]+(?:\s+-\s+[\u0980-\u09FF]+)?)',
    );
    int lastIndex = 0;

    for (final match in pattern.allMatches(text)) {
      if (match.start > lastIndex) {
        spans.add(
          TextSpan(text: text.substring(lastIndex, match.start), style: style),
        );
      }

      final token = match.group(0)!;
      if (token.startsWith('http://') || token.startsWith('https://')) {
        spans.add(
          TextSpan(
            text: token,
            style: style.copyWith(
              color: colors.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      } else if (token.startsWith('@')) {
        final isMeMention =
            currentUserId != null &&
            token.toLowerCase().contains(currentUserId!.toLowerCase());

        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Container(
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isMeMention
                    ? Colors.amber.withValues(alpha: 0.25)
                    : colors.primaryContainer.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                token,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isMeMention ? Colors.amber.shade300 : colors.primary,
                ),
              ),
            ),
          ),
        );
      }

      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.add(TextSpan(text: text.substring(lastIndex), style: style));
    }

    return spans;
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
    if (conversation.isGroupConversation) {
      return GroupAvatarStack(
        avatars: conversation.memberAvatars,
        avatarUrl: conversation.avatarUrl,
        name: title,
        size: 52,
      );
    }
    // The "peer" of a note to self is the viewer, so their own picture with
    // their own presence dot on it would be the avatar. Signal draws a
    // bookmark instead, and so do we.
    if (conversation.isSelf) {
      return NoteToSelfAvatar(size: 52, iconSize: 24);
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
