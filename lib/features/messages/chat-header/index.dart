import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/chat_models.dart';
import '../providers/chat_provider.dart';
import 'group-details-dialog.dart';
import 'dm-actions-sheet.dart';

class ChatHeader extends ConsumerWidget {
  const ChatHeader({super.key, required this.conversation});
  final ChatConversation conversation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = conversation.displayTitle(ref.watch(chatProvider).currentUserId);

    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          if (conversation.isChannel && conversation.memberCount != null)
            Text(
              '${conversation.memberCount} members',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
      actions: [
        if (conversation.muted)
          const Padding(
            padding: EdgeInsets.only(right: 4),
            child: Icon(Icons.notifications_off_outlined, size: 18),
          ),
        IconButton(
          icon: const Icon(Icons.more_vert_rounded),
          onPressed: () async {
            if (conversation.isChannel) {
              await showGroupDetailsDialog(context, ref, conversation);
            } else {
              await showDmActionsSheet(context, ref, conversation);
            }
          },
        ),
      ],
    );
  }
}
