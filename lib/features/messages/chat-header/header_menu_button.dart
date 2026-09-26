import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../chat-list/chat_search.dart';
import '../chat-mute/mute_choice.dart';
import '../chat-mute/mute_flow.dart';
import '../chat-timeline/pinned_message_actions.dart';
import '../chat_icon.dart';
import '../data/models/chat_models.dart';

enum _HeaderAction { mute, search }

/// The ⋮ at the end of the chat header. Opens a bottom sheet — never a popup
/// menu — and, like the chat-list long press, the sheet only chooses: the
/// header's own context carries the action out once it has closed.
class HeaderMenuButton extends ConsumerWidget {
  const HeaderMenuButton({
    super.key,
    required this.conversation,
    required this.title,
  });

  final ChatConversation conversation;
  final String title;

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final action = await showModalBottomSheet<_HeaderAction>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => _HeaderSheet(conversation: conversation),
    );
    if (action == null || !context.mounted) return;
    switch (action) {
      case _HeaderAction.mute:
        await changeConversationMute(context, ref, conversation);
      case _HeaderAction.search:
        final messageId = await openChatSearch(
          context,
          ref,
          conversationId: conversation.id,
          conversationTitle: title,
        );
        if (messageId != null && context.mounted) {
          await jumpToPinnedMessage(context, ref, messageId);
        }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Compact: it shares the trailing row with the call pill, and a full
    // 48dp target squeezes the title on a narrow phone.
    return IconButton(
      tooltip: 'More',
      visualDensity: VisualDensity.compact,
      onPressed: () => _open(context, ref),
      icon: ChatIcon(
        HugeIcons.strokeRoundedMoreVertical,
        size: 20,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }
}

class _HeaderSheet extends StatelessWidget {
  const _HeaderSheet({required this.conversation});

  final ChatConversation conversation;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final muted = conversation.isMutedNow;
    void choose(_HeaderAction a) => Navigator.of(context).pop(a);
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: ChatIcon(
              muted
                  ? HugeIcons.strokeRoundedNotification01
                  : HugeIcons.strokeRoundedNotificationOff01,
              size: 20,
              color: colors.onSurface,
            ),
            title: Text(muted ? 'Unmute notifications' : 'Mute notifications'),
            subtitle: muted ? Text(conversation.muteStatusLabel ?? '') : null,
            onTap: () => choose(_HeaderAction.mute),
          ),
          ListTile(
            leading: ChatIcon(
              HugeIcons.strokeRoundedSearch01,
              size: 20,
              color: colors.onSurface,
            ),
            title: const Text('Search in chat'),
            onTap: () => choose(_HeaderAction.search),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
