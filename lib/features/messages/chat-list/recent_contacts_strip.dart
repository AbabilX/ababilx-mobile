import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/app_avatar.dart';
import '../data/models/chat_models.dart';
import '../nickname/contact_nickname_provider.dart';
import '../nickname/nickname_title.dart';

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

class RecentContactTile extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final title = ref
        .watch(contactNicknamesProvider)
        .titleFor(conversation, currentUserId);
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
