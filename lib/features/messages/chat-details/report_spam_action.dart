import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/app_toast.dart';
import '../chat_icon.dart';
import '../data/models/chat_models.dart';
import '../providers/chat_connections_provider.dart';
import '../providers/chat_details_provider.dart';
import 'details_tile.dart';

/// Signal's "Report spam", offered beside Block and deliberately separate from
/// it: a block is the reporter's own recourse and takes effect at once, while
/// a report is a message to whoever runs the service. The dialog lets one tap
/// do both, because that is almost always what a person means.
///
/// The report carries no message content and cannot — a personal DM or group
/// is end-to-end encrypted, so the server holds ciphertext.
class DetailsReportTile extends ConsumerWidget {
  const DetailsReportTile({super.key, required this.conversation});

  final ChatConversation conversation;

  bool get _canBlock =>
      conversation.isDm && (conversation.peerUserId ?? '').isNotEmpty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DetailsTile(
      icon: const ChatIcon(HugeIcons.strokeRoundedAlert02),
      title: 'Report spam',
      destructive: true,
      onTap: () => _confirm(context, ref),
    );
  }

  Future<void> _confirm(BuildContext context, WidgetRef ref) async {
    final colors = Theme.of(context).colorScheme;
    final choice = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Report spam?'),
        content: Text(
          _canBlock
              ? 'We will be told that you reported this conversation. Your '
                    'messages stay encrypted, so no one can read them. '
                    'Blocking also stops them messaging or calling you.'
              : 'We will be told that you reported this group. Your messages '
                    'stay encrypted, so no one can read them.',
          style: const TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, 'report'),
            child: const Text('Report'),
          ),
          if (_canBlock)
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: colors.error),
              onPressed: () => Navigator.pop(dialog, 'block'),
              child: const Text('Report and block'),
            ),
        ],
      ),
    );
    if (choice == null || !context.mounted) return;
    await _send(context, ref, block: choice == 'block');
  }

  Future<void> _send(
    BuildContext context,
    WidgetRef ref, {
    required bool block,
  }) async {
    try {
      await ref
          .read(chatDetailsApiProvider)
          .reportConversation(conversation.id, block: block);
    } catch (e) {
      if (context.mounted) showAppToast(context, 'Failed: $e', isError: true);
      return;
    }
    if (block) {
      // The server placed the block; this pulls the local connection lists
      // back in line so the composer and People screen agree with it.
      await ref.read(chatConnectionsProvider.notifier).refresh();
    }
    if (!context.mounted) return;
    showAppToast(context, block ? 'Reported and blocked' : 'Reported');
    // A blocked conversation has nothing left to do on this screen; a plain
    // report leaves the chat exactly as it was, so stay put.
    if (block) context.go('/messages');
  }
}
