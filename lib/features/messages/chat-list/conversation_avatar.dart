import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../shared/widgets/app_avatar.dart';
import '../../presence/online_dot.dart';
import '../../presence/online_presence_provider.dart';
import '../../privacy-mode/peer_privacy_provider.dart';
import '../chat_icon.dart';
import '../data/models/chat_models.dart';
import '../note_to_self_avatar.dart';
import 'group_avatar_stack.dart';

/// The picture at the start of a chat-list row, with the peer's online dot
/// on a DM.
class ConversationAvatar extends ConsumerWidget {
  const ConversationAvatar({
    super.key,
    required this.conversation,
    required this.title,
  });

  final ChatConversation conversation;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    if (conversation.isGroupConversation) {
      return GroupAvatarStack(
        avatars: conversation.memberAvatars,
        avatarUrl: conversation.avatarUrl,
        name: title,
        webhook: conversation.isWebhook,
        size: 52,
      );
    }
    // The "peer" of a note to self is the viewer, so their own picture with
    // their own presence dot on it would be the avatar. Signal draws a
    // bookmark instead, and so do we.
    if (conversation.isSelf) {
      return NoteToSelfAvatar(size: 52, iconSize: 24);
    }
    final deleted = conversation.isAccountDeleted;
    // A private peer (server 0152) is never reported online to us; the check
    // is here too so a live flip hides a dot drawn a moment before it.
    final online =
        conversation.hasDmPeer &&
        !deleted &&
        !ref.watch(conversationPeerPrivacyProvider(conversation.id)) &&
        ref.watch(isUserOnlineProvider(conversation.peerUserId));
    final avatar = AppAvatar(
      size: 52,
      url: deleted ? null : conversation.peerUserAvatar,
      name: deleted ? null : title,
      fallback: ChatIcon(
        HugeIcons.strokeRoundedUser02,
        color: colors.onSurfaceVariant,
      ),
    );
    // Always a Stack, so the dot coming and going never remounts the picture.
    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        if (online) const Positioned(right: -2, bottom: -2, child: OnlineDot()),
      ],
    );
  }
}
