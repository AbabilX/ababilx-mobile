import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../group-member-permissions/group_member_tags_provider.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../chat_icon.dart';
import '../chat_utils.dart';
import '../data/models/chat_models.dart';
import '../providers/chat_provider.dart';
import 'bubble_side_indicators.dart';
import 'message_bubble.dart';
import 'message_bubble_content.dart';
import 'message_sender_label.dart';
import 'reaction_details_sheet.dart';
import 'reaction_row.dart';
import 'sender_name_color.dart';
import 'signal_bubble_metrics.dart';
import 'unsealed_message_mark.dart';
import 'user_profile_sheet.dart';
import '../nickname/contact_nickname_provider.dart';

/// Signal's conversation item: your messages right, theirs left, avatars only
/// in groups and only under the last bubble of a run, the sender's name only
/// above the first.
class MessageRowContent extends ConsumerWidget {
  const MessageRowContent({
    super.key,
    required this.message,
    required this.pulse,
    required this.isSending,
    required this.isFailed,
    required this.isOwnMessage,
    this.clusterPosition = MessageClusterPosition.single,
    this.isGroup = false,
    this.hasWallpaper = false,
    this.onOpenThread,
  });

  final ChatMessage message;
  final Animation<double> pulse;
  final bool isSending;
  final bool isFailed;
  final bool isOwnMessage;
  final MessageClusterPosition clusterPosition;
  final bool isGroup;
  final bool hasWallpaper;
  final VoidCallback? onOpenThread;

  bool get _startsCluster =>
      clusterPosition == MessageClusterPosition.single ||
      clusterPosition == MessageClusterPosition.start;

  bool get _endsCluster =>
      clusterPosition == MessageClusterPosition.single ||
      clusterPosition == MessageClusterPosition.end;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    // A webhook message has no sender: no user id, no user name, and nobody to
    // open a profile for. Its name is the feed's, carried in meta.
    final webhook = message.isWebhook;
    final name = webhook
        ? (message.webhookSourceName ?? 'Flock')
        : ref
              .watch(contactNicknamesProvider)
              .resolve(userId: message.userId, name: message.userName);
    // A feed's picture belongs to the feed, not to one of its messages. The
    // URL joined onto a message is whatever the hook wore when that message
    // was fetched, so a photo set today would never reach the ones already in
    // the local store — and a photo removed today would go on showing on them.
    final feed = webhook
        ? ref.watch(
            chatProvider.select(
              (c) => c.conversationById(message.conversationId),
            ),
          )
        : null;
    final avatarUrl = feed != null ? feed.avatarUrl : message.userAvatarUrl;
    final colors = SignalBubbleColors.of(scheme, hasWallpaper: hasWallpaper);
    // A name over an incoming bubble in a group, an avatar under the last one.
    final showName = isGroup && !isOwnMessage && _startsCluster;
    final showAvatar = isGroup && !isOwnMessage;
    // The author's member tag (server 0157): the live map first, since the
    // copy on a stored message is whatever it was when it was fetched.
    final tag = showName && !webhook
        ? (ref.watch(
                groupMemberTagsProvider.select(
                  (m) => m[message.conversationId]?[message.userId],
                ),
              ) ??
              message.senderTag ??
              '')
        : '';

    void showProfile() {
      if (webhook) return;
      showUserProfileSheet(
        context: context,
        ref: ref,
        userId: message.userId,
        userName: name,
        userAvatarUrl: message.userAvatarUrl,
      );
    }

    final column = Column(
      crossAxisAlignment: isOwnMessage
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showName)
          MessageSenderLabel(
            name: name,
            tag: tag,
            color: webhook ? scheme.primary : senderNameColor(message.userId),
            onTap: showProfile,
          ),
        // Bubble + reactions share one width (the bubble's). Reactions always
        // sit on the trailing edge — left-aligned peer columns used to park
        // the pill under the bubble's leading corner.
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            BubbleSideIndicators(
              message: message,
              isOwn: isOwnMessage,
              onOpenThread: onOpenThread,
              child: MessageBubble(
                isOwn: isOwnMessage,
                clusterPosition: clusterPosition,
                colors: colors,
                dimmed:
                    isSending &&
                    message.sendStatus != MessageSendStatus.uploading,
                transparent: isBareMediaBubble(message),
                child: MessageBubbleContent(
                  message: message,
                  colors: colors,
                  isOwn: isOwnMessage,
                  isSending: isSending,
                  isFailed: isFailed,
                  pulse: pulse,
                  showFooter: _endsCluster || isSending || isFailed,
                ),
              ),
            ),
            if (!message.isDeleted && message.reactions.isNotEmpty)
              ReactionRow(
                reactions: message.reactions,
                hasWallpaper: hasWallpaper,
                onOpen: (emoji) => showReactionDetailsSheet(
                  context: context,
                  messageId: message.id,
                  initialEmoji: emoji,
                ),
              ),
          ],
        ),
        UnsealedMessageMark(message: message),
      ],
    );

    return Padding(
      // The long-press overlay hides this row and floats its own copy, so
      // there is nothing to highlight in place.
      padding: EdgeInsets.only(top: signalBubbleTopSpacing(clusterPosition)),
      child: Row(
        mainAxisAlignment: isOwnMessage
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (showAvatar) ...[
            // The slot is held for every message of the run so the bubbles
            // stay in one column; only the last one draws a face.
            SizedBox(
              width: SignalBubbleMetrics.avatarSize,
              child: _endsCluster
                  ? GestureDetector(
                      onTap: showProfile,
                      child: ClipOval(
                        child: AppAvatar(
                          size: SignalBubbleMetrics.avatarSize,
                          url: avatarUrl,
                          name: name,
                          // A feed with no picture has no initial worth
                          // drawing — the Flock glyph, same as its pill.
                          fallback: webhook
                              ? ChatIcon(
                                  HugeIcons.strokeRoundedWebhook,
                                  size: SignalBubbleMetrics.avatarSize * 0.5,
                                  color: scheme.primary,
                                )
                              : null,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(child: column),
        ],
      ),
    );
  }
}
