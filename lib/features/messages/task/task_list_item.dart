import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../chat-timeline/message_bubble.dart';
import '../data/models/chat_message.dart';
import '../nickname/contact_nickname_provider.dart';
import '../providers/chat_provider.dart';
import '../chat_icon.dart';
import '../../../shared/widgets/app_capsule.dart';
import 'task_card.dart';
import 'task_card_data.dart';
import 'task_icons.dart';
import 'task_list_provider.dart';
import 'task_strings.dart';

/// One task on the Tasks page: who gave it, the card itself, and the way
/// back to it in the chat.
class TaskListItem extends ConsumerWidget {
  const TaskListItem({
    super.key,
    required this.message,
    required this.onChanged,
    required this.onOpen,
  });

  final ChatMessage message;
  final ValueChanged<ChatMessage> onChanged;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final s = TaskStrings.of(ref.watch(appLanguageProvider));
    // The open timeline's copy wins: a change from the other person lands
    // there over the socket.
    final live = ref.watch(
      liveTaskProvider((
        conversationId: message.conversationId,
        messageId: message.id,
      )),
    );
    final shown = live ?? message;
    final task = TaskCardData.of(shown);
    if (task == null) return const SizedBox.shrink();
    final own =
        shown.userId == ref.watch(chatProvider.select((c) => c.currentUserId));
    final from = own
        ? s.fromYou
        : s.from(
            ref
                .watch(contactNicknamesProvider)
                .resolve(userId: shown.userId, name: shown.userName),
          );
    final colors = SignalBubbleColors.of(scheme, hasWallpaper: false);
    return Material(
      color: colors.background,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            TaskCard(
              message: shown,
              task: task,
              colors: colors,
              onChanged: onChanged,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    from,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: colors.muted),
                  ),
                ),
                AppCapsule(
                  label: s.openInChat,
                  onTap: onOpen,
                  trailing: const ChatIcon(TaskIcons.open, size: 16),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
