import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../messages/chat_icon.dart';
import '../providers/ghost_provider.dart';
import 'ghost_labels.dart';

/// Says what a Ghost Chat is before the other person's screen is taken over.
///
/// The invite is a full-screen interruption on their phone, so it is never one
/// stray tap away from the attachment panel.
Future<void> showGhostIntroSheet(
  BuildContext context, {
  required String conversationId,
}) => showModalBottomSheet<void>(
  context: context,
  useRootNavigator: true,
  showDragHandle: true,
  builder: (_) => _GhostIntroSheet(conversationId: conversationId),
);

class _GhostIntroSheet extends ConsumerWidget {
  const _GhostIntroSheet({required this.conversationId});

  final String conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ChatIcon(
              HugeIcons.strokeRoundedIncognito,
              size: 44,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              ghostText(ref, 'ghost_intro_title'),
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              ghostText(ref, 'ghost_intro_body'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  ref.read(ghostProvider.notifier).invite(conversationId);
                },
                child: Text(ghostText(ref, 'ghost_intro_start')),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(ghostText(ref, 'ghost_cancel')),
            ),
          ],
        ),
      ),
    );
  }
}
