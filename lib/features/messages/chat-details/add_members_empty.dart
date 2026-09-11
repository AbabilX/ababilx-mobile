import 'package:flutter/material.dart';

import '../data/models/chat_models.dart';

/// Why there is nobody to add. Two different answers, because "no rows" on
/// its own read as a broken sheet.
class AddMembersEmpty extends StatelessWidget {
  const AddMembersEmpty({
    super.key,
    required this.conversation,
    required this.filtered,
  });

  final ChatConversation conversation;
  final bool filtered;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = filtered
        ? 'Nobody by that name is left to add.'
        : 'Everyone you are connected with is already in this group. '
              'Connect with someone in People first.';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: colors.onSurfaceVariant),
        ),
      ),
    );
  }
}
