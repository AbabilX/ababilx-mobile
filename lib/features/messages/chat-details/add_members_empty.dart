import 'package:flutter/material.dart';

import '../data/models/chat_models.dart';

/// Why there is nobody to add. Three different answers, because "no rows"
/// on its own read as a broken sheet.
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
        : conversation.isPersonal
        ? 'Everyone you are connected with is already in this group. '
              'Connect with someone in People first.'
        : 'Everyone in this workspace is already in this channel.';
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
