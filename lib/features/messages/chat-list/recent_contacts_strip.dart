import 'package:flutter/material.dart';

import '../../../shared/widgets/app_avatar.dart';
import '../data/models/chat_models.dart';

class RecentContactsStrip extends StatelessWidget {
  const RecentContactsStrip({
    super.key,
    required this.conversations,
    required this.onTap,
    this.currentUserId,
  });

  final List<ChatConversation> conversations;
  final void Function(ChatConversation) onTap;
  final String? currentUserId;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        itemCount: conversations.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (_, i) {
          final c = conversations[i];
          return RecentContactTile(
            conversation: c,
            currentUserId: currentUserId,
            onTap: () => onTap(c),
          );
        },
      ),
    );
  }
}

class RecentContactTile extends StatelessWidget {
  const RecentContactTile({
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
    final title = conversation.displayTitle(currentUserId);
    final avatar = conversation.peerUserAvatar;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppAvatar.radius),
      child: SizedBox(
        width: 64,
        child: Column(
          children: [
            AppAvatar(size: 56, url: avatar, name: title),
            const SizedBox(height: 6),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
