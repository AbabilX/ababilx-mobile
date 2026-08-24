import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../data/models/chat_models.dart';

/// Swipe-right (any tile) → pinned "Read" action button.
/// Swipe-left → pinned "Leave" (groups) or "Remove" (DMs, "delete for me" —
/// reappears once the peer sends a new message).
class ConversationRowSwipe extends StatelessWidget {
  const ConversationRowSwipe({
    super.key,
    required this.conversation,
    required this.onMarkRead,
    required this.onLeaveChannel,
    required this.onRemoveDm,
    required this.child,
  });

  final ChatConversation conversation;
  final VoidCallback onMarkRead;
  final VoidCallback onLeaveChannel;
  final VoidCallback onRemoveDm;
  final Widget child;

  Future<void> _confirmEndAction(BuildContext context) async {
    final isChannel = conversation.isGroupConversation;
    final title = isChannel ? 'Leave group?' : 'Remove conversation?';
    final message = isChannel
        ? 'You will stop receiving messages from "${conversation.displayTitle(null)}".'
        : 'This removes "${conversation.displayTitle(null)}" from your list. '
              'It comes back if they message you again.';
    final actionLabel = isChannel ? 'Leave' : 'Remove';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (isChannel) {
      onLeaveChannel();
    } else {
      onRemoveDm();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Always swipeable on every DM and group tile, read or not — this is
    // a gesture affordance, not something gated on current unread state.
    return Slidable(
      key: key!,
      startActionPane: ActionPane(
        motion: const ScrollMotion(),
        extentRatio: 0.28,
        children: [
          SlidableAction(
            onPressed: (_) => onMarkRead(),
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            icon: Icons.done_all_rounded,
            label: 'Read',
          ),
        ],
      ),
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        extentRatio: 0.28,
        children: [
          SlidableAction(
            onPressed: (ctx) => _confirmEndAction(ctx),
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            icon: conversation.isGroupConversation
                ? Icons.logout_rounded
                : Icons.delete_outline_rounded,
            label: conversation.isGroupConversation ? 'Leave' : 'Remove',
          ),
        ],
      ),
      child: child,
    );
  }
}
