import 'package:flutter/material.dart';

import '../data/models/chat_models.dart';

/// The confirmation for the one action that ends a conversation — leaving a
/// group, or deleting a DM for yourself.
///
/// Shared by the swipe lane and the long-press sheet on purpose. They are two
/// gestures onto the same destructive action, and two copies of the wording
/// is how one of them ends up promising something the other does not.
Future<bool> confirmConversationEndAction(
  BuildContext context,
  ChatConversation conversation,
  String title,
) async {
  final isGroup = conversation.isGroupConversation;
  final selfNote = conversation.isSelf;

  final dialogTitle = isGroup
      ? 'Leave group?'
      : selfNote
      ? 'Delete your notes?'
      : 'Delete chat?';
  final message = isGroup
      ? 'You will stop receiving messages from "$title".'
      : selfNote
      ? 'Every note and file you saved here is deleted from this device and '
            'from your account. Nobody else ever had a copy, so this cannot '
            'be undone.'
      : 'The messages and files in "$title" are deleted from this device and '
            'from your account, and cannot be restored. The other person '
            'keeps their own copy.';

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(dialogTitle),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(ctx).colorScheme.error,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(isGroup ? 'Leave' : 'Delete'),
        ),
      ],
    ),
  );
  return ok == true;
}
