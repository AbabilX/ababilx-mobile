import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../data/models/chat_models.dart';
import 'conversation_end_action.dart';

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
    // Same dialog the long-press sheet raises — one wording for one action.
    final ok = await confirmConversationEndAction(
      context,
      conversation,
      conversation.displayTitle(null),
    );
    if (!ok) return;
    if (conversation.isGroupConversation) {
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
