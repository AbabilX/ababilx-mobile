import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

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
        separatorBuilder: (_, __) => const SizedBox(width: 14),
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
    final colors = Theme.of(context).colorScheme;
    final avatar = conversation.peerUserAvatar;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 64,
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 56,
                height: 56,
                child: avatar != null
                    ? CachedNetworkImage(imageUrl: avatar, fit: BoxFit.cover)
                    : ColoredBox(
                        color: colors.surfaceContainerHighest,
                        child: Center(
                          child: Text(
                            title.isNotEmpty ? title[0].toUpperCase() : '?',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
              ),
            ),
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
