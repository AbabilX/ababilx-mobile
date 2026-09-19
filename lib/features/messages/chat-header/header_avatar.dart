import 'package:flutter/material.dart';

import '../../../shared/widgets/app_avatar.dart';
import '../chat-list/group_avatar_stack.dart';
import '../data/models/chat_models.dart';
import '../note_to_self_avatar.dart';

/// The small picture beside the conversation name in the top bar.
///
/// It follows exactly the same precedence as the conversation list — a group's
/// own photo first, the member montage only as its fallback — because a photo
/// that shows in one place and not the other reads as a bug in whichever place
/// you happen to be looking at.
class ChatHeaderAvatar extends StatelessWidget {
  const ChatHeaderAvatar({
    super.key,
    required this.conversation,
    required this.title,
    this.size = 30,
  });

  final ChatConversation conversation;
  final String title;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (conversation.isGroupConversation) {
      return GroupAvatarStack(
        avatars: conversation.memberAvatars,
        avatarUrl: conversation.avatarUrl,
        name: title,
        size: size,
      );
    }
    if (conversation.isSelf) {
      return NoteToSelfAvatar(size: size, iconSize: size * 0.55);
    }
    return ClipOval(
      child: AppAvatar(
        size: size,
        url: conversation.isAccountDeleted ? null : conversation.peerUserAvatar,
        name: conversation.isAccountDeleted ? null : title,
        fallback: conversation.isAccountDeleted
            ? Icon(
                Icons.person_outline_rounded,
                size: size * 0.55,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              )
            : null,
      ),
    );
  }
}
