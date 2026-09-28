import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:go_router/go_router.dart';

import '../chat_icon.dart';
import '../data/models/chat_models.dart';
import '../providers/chat_provider.dart';
import 'details_block_tile.dart';
import 'details_tile.dart';
import 'group_permissions.dart';
import 'report_spam_action.dart';

/// The red block at the bottom. Every one of these ends the screen, so they
/// all confirm first and then leave for the chat list — there is nothing left
/// to come back to.
class DetailsDangerActions extends ConsumerWidget {
  const DetailsDangerActions({super.key, required this.conversation});

  final ChatConversation conversation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final group = conversation.isGroupConversation;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (group)
          DetailsTile(
            icon: const ChatIcon(HugeIcons.strokeRoundedLogout01),
            title: 'Leave group',
            destructive: true,
            onTap: () => _confirm(
              context,
              ref,
              title: 'Leave group?',
              body:
                  'You will stop receiving messages from this group. The '
                  'conversation stays for everyone else.',
              action: 'Leave',
              run: () =>
                  ref.read(chatProvider.notifier).leaveChannel(conversation.id),
            ),
          )
        else ...[
          DetailsTile(
            icon: const ChatIcon(HugeIcons.strokeRoundedDelete02),
            title: conversation.isSelf ? 'Delete notes' : 'Delete chat',
            destructive: true,
            onTap: () => _confirm(
              context,
              ref,
              title: conversation.isSelf
                  ? 'Delete your notes?'
                  : 'Delete chat?',
              body: conversation.isSelf
                  ? 'Every note and file you saved here is deleted from this '
                        'device and from your account. Nobody else ever had a '
                        'copy, so this cannot be undone.'
                  : 'The messages and files are deleted from this device and '
                        'from your account, and cannot be restored. The other '
                        'person keeps their own copy. If they message you '
                        'again the chat returns empty.',
              action: 'Delete',
              run: () =>
                  ref.read(chatProvider.notifier).hideDm(conversation.id),
            ),
          ),
          if (conversation.isPersonal &&
              conversation.hasDmPeer &&
              !conversation.isAccountDeleted)
            DetailsBlockTile(conversation: conversation),
        ],
        // Report sits with the other red rows but ends nothing: filing one
        // leaves the conversation exactly as it was unless the person also
        // chose to block. There is nobody to report in a note to self.
        if (!conversation.isSelf && !conversation.isAccountDeleted)
          DetailsReportTile(conversation: conversation),
        if (group && GroupPermissions(conversation).canManage)
          DetailsTile(
            icon: const ChatIcon(HugeIcons.strokeRoundedDelete04),
            title: 'Delete group',
            destructive: true,
            onTap: () => _confirm(
              context,
              ref,
              title: 'Delete group?',
              body:
                  'All messages, attachments and members are removed for '
                  'everyone. This cannot be undone.',
              action: 'Delete group',
              run: () => ref
                  .read(chatProvider.notifier)
                  .deleteChannel(conversation.id),
            ),
          ),
      ],
    );
  }

  Future<void> _confirm(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required String body,
    required String action,
    required Future<void> Function() run,
  }) async {
    final colors = Theme.of(context).colorScheme;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(title),
        content: Text(body, style: const TextStyle(height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: colors.error),
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(action),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await run();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed: $e')));
      return;
    }
    if (!context.mounted) return;
    // The details screen sits on top of the conversation, and both are gone
    // now, so unwind to the list rather than popping back into a dead chat.
    context.go('/messages');
  }
}
