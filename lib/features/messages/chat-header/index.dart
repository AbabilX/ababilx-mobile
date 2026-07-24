import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../chat_icon.dart';
import '../data/models/chat_models.dart';
import '../providers/chat_provider.dart';
import 'dm-actions-sheet.dart';
import 'group-details-dialog.dart';

class ChatHeader extends ConsumerWidget {
  const ChatHeader({super.key, required this.conversation});
  final ChatConversation conversation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title =
        conversation.displayTitle(ref.watch(chatProvider).currentUserId);
    final colors = Theme.of(context).colorScheme;

    return AppBar(
      centerTitle: true,
      title: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          if (conversation.isChannel && conversation.memberCount != null)
            Text(
              '${conversation.memberCount} members',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: colors.onSurfaceVariant,
              ),
            ),
        ],
      ),
      actions: [
        if (conversation.muted)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: ChatIcon(
              HugeIcons.strokeRoundedNotificationOff01,
              size: 18,
              color: colors.onSurfaceVariant,
            ),
          ),
        IconButton(
          icon: const ChatIcon(HugeIcons.strokeRoundedMoreVertical),
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
