import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../shared/widgets/app_avatar.dart';
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
    final avatar = conversation.peerUserAvatar;

    return AppBar(
      titleSpacing: 0,
      title: Row(
        children: [
          if (conversation.isDm)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: AppAvatar(size: 32, url: avatar, name: title),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (conversation.isChannel && conversation.memberCount != null)
                  Text(
                    '${conversation.memberCount} members',
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        if (conversation.muted)
          ChatIcon(
            HugeIcons.strokeRoundedNotificationOff01,
            size: 18,
            color: colors.onSurfaceVariant,
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
