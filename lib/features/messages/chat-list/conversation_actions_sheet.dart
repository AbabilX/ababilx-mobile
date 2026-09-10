import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../chat_icon.dart';
import '../data/models/chat_models.dart';

/// What a long press on a conversation row can ask for.
///
/// Deliberately absent, and each for a reason worth keeping: **Archive**,
/// because there is no per-user archive — `chat_conversations.archived_at`
/// archives a group for everyone in it, so the row would either do nothing or
/// hide the chat from the other person; **Mark as unread**, because nothing on
/// the server stores it. A dead menu row is worse than a missing one.
enum ConversationAction { pin, unpin, mute, unmute, markRead, end }

/// Signal's long press, as a sheet for the row that was pressed rather than an
/// action mode over a selection.
///
/// It only *chooses*. Every action is carried out by the caller with the
/// caller's context, because the sheet's own context is dead the moment it
/// pops — and a pin refused by the server has to report that afterwards.
Future<ConversationAction?> showConversationActionsSheet(
  BuildContext context,
  ChatConversation conversation,
  String title,
) {
  return showModalBottomSheet<ConversationAction>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
          ..._tiles(sheetContext, conversation),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

List<Widget> _tiles(BuildContext context, ChatConversation conversation) {
  void choose(ConversationAction action) => Navigator.of(context).pop(action);
  final pinned = conversation.pinned;
  final muted = conversation.muted;
  final isGroup = conversation.isGroupConversation;

  return [
    _ActionTile(
      icon: pinned ? HugeIcons.strokeRoundedPinOff : HugeIcons.strokeRoundedPin,
      label: pinned ? 'Unpin chat' : 'Pin chat',
      onTap: () =>
          choose(pinned ? ConversationAction.unpin : ConversationAction.pin),
    ),
    _ActionTile(
      icon: muted
          ? HugeIcons.strokeRoundedNotification01
          : HugeIcons.strokeRoundedNotificationOff01,
      label: muted ? 'Unmute notifications' : 'Mute notifications',
      onTap: () =>
          choose(muted ? ConversationAction.unmute : ConversationAction.mute),
    ),
    if (conversation.unreadCount > 0)
      _ActionTile(
        icon: HugeIcons.strokeRoundedCheckmarkCircle02,
        label: 'Mark as read',
        onTap: () => choose(ConversationAction.markRead),
      ),
    _ActionTile(
      icon: isGroup
          ? HugeIcons.strokeRoundedLogout01
          : HugeIcons.strokeRoundedDelete02,
      label: isGroup
          ? 'Leave group'
          : conversation.isSelf
          ? 'Delete notes'
          : 'Delete chat',
      destructive: true,
      onTap: () => choose(ConversationAction.end),
    ),
  ];
}

/// A menu row, not a settings row — which is why it does not reuse the details
/// screen's tile: that one carries a value on the right and reads as state.
class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final List<List<dynamic>> icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = destructive ? colors.error : colors.onSurface;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            ChatIcon(icon, size: 20, color: color),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
