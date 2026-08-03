import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../data/models/chat_models.dart';

/// Swipe-right (unread tiles) → pinned "Read" action button.
/// Swipe-left (channels only) → pinned "Leave" action button.
/// DMs have no server-side delete/hide, so they never swipe-left.
class ConversationRowSwipe extends StatelessWidget {
  const ConversationRowSwipe({
    super.key,
    required this.conversation,
    required this.onMarkRead,
    required this.onLeaveChannel,
    required this.child,
  });

  final ChatConversation conversation;
  final VoidCallback onMarkRead;
  final VoidCallback onLeaveChannel;
  final Widget child;

  Future<void> _confirmLeave(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave group?'),
        content: Text(
          'You will stop receiving messages from "${conversation.displayTitle(null)}".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (ok == true) onLeaveChannel();
  }

  @override
  Widget build(BuildContext context) {
    final canLeave = conversation.isChannel;

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
      endActionPane: canLeave
          ? ActionPane(
              motion: const ScrollMotion(),
              extentRatio: 0.28,
              children: [
                SlidableAction(
                  onPressed: (ctx) => _confirmLeave(ctx),
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  icon: Icons.logout_rounded,
                  label: 'Leave',
                ),
              ],
            )
          : null,
      child: child,
    );
  }
}
