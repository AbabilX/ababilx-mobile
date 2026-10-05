import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../../khaam/providers/khaam_providers.dart';
import '../../privacy-mode/peer_privacy_provider.dart';
import '../../calls/providers/in_call_presence_provider.dart';
import '../../calls/widgets/in_call_label.dart';
import '../../local_share/providers/local_share_providers.dart';
import '../../profile/providers/user_status_provider.dart';
import '../../profile/widgets/user_status_badge.dart';
import '../chat-mute/mute_choice.dart';
import '../chat_icon.dart';
import '../chat_list_filters.dart';
import '../chat_unread_badge.dart';
import '../data/models/chat_models.dart';
import 'conversation_avatar.dart';
import 'conversation_preview_line.dart';
import '../nickname/contact_nickname_provider.dart';
import '../nickname/nickname_title.dart';
import '../chat-typing/typing_text.dart';

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
    final preview = chatListPreview(
      conversation,
      currentUserId,
      lang: ref.watch(appLanguageProvider),
      openedKhaams: ref.watch(khaamOpenedIdsProvider).valueOrNull ?? const {},
    );
    final typingText = conversation.isSelf || conversation.isWebhook
        ? ''
        : watchTypingText(
            ref,
            conversation.id,
            isGroup: conversation.isGroupConversation,
          );
    final time = relativeChatTime(conversation.lastMessageAt);
    final unread = conversation.unreadCount > 0;
    // A private peer (server 0152) leaks nothing here either.
    final peerPrivate = ref.watch(
      conversationPeerPrivacyProvider(conversation.id),
    );
    final peerInCall =
        conversation.hasDmPeer &&
        !peerPrivate &&
        ref.watch(isUserInCallProvider(conversation.peerUserId));
    final peerStatus = conversation.hasDmPeer && !peerInCall && !peerPrivate
        ? ref.watch(userStatusForProvider(conversation.peerUserId))
        : null;

    // The peer has a device on this Wi-Fi with Local Share on. Matched by the
    // account id the device announces — a claim, so it only decorates a chat
    // that already exists.
    final isLocalPeerNearby =
        conversation.hasDmPeer &&
        (ref.watch(localSharePeersProvider).valueOrNull?.values ?? const [])
            .any((d) => d.userId == conversation.peerUserId);

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
            ConversationAvatar(conversation: conversation, title: title),
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
                              flex: 3,
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
                              // Flexible, or a long status pushes the row
                              // past the timestamp instead of ending in "…".
                              Flexible(
                                flex: 2,
                                child: UserStatusBadge(
                                  status: peerStatus,
                                  compact: true,
                                ),
                              ),
                            ],
                            if (conversation.isMutedNow)
                              Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: ChatIcon(
                                  conversation.isMentionsOnlyMute
                                      ? HugeIcons.strokeRoundedAt
                                      : HugeIcons
                                            .strokeRoundedNotificationOff01,
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
                        child: typingText.isNotEmpty
                            ? Text(
                                typingText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: previewStyle.copyWith(
                                  color: colors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              )
                            : ConversationPreviewLine(
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
