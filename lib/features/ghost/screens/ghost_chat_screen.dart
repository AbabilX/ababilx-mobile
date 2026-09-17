import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../messages/chat_icon.dart';
import '../providers/ghost_provider.dart';
import '../providers/ghost_state.dart';
import '../protocol/ghost_cluster.dart';
import '../widgets/ghost_bubble.dart';
import '../widgets/ghost_composer.dart';
import '../widgets/ghost_ended_view.dart';
import '../widgets/ghost_header.dart';
import '../widgets/ghost_labels.dart';

/// The whole Ghost Chat on the inviter's and the joiner's phone alike: waiting,
/// connecting, the conversation, and what is left after the burn.
class GhostChatScreen extends ConsumerWidget {
  const GhostChatScreen({super.key});

  Future<void> _back(BuildContext context, WidgetRef ref) async {
    final state = ref.read(ghostProvider);
    final notifier = ref.read(ghostProvider.notifier);
    if (state.phase == GhostPhase.ended) {
      notifier.close();
      return;
    }
    // An invite nobody has answered holds no content: nothing to warn about.
    if (state.phase == GhostPhase.inviting || state.items.isEmpty) {
      notifier.leave();
      return;
    }
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(ghostText(ref, 'ghost_leave_title')),
        content: Text(ghostText(ref, 'ghost_leave_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text(ghostText(ref, 'ghost_cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(dialog).colorScheme.error,
            ),
            child: Text(ghostText(ref, 'ghost_leave')),
          ),
        ],
      ),
    );
    if (leave == true) notifier.leave();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ghostProvider);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back(context, ref);
      },
      child: Scaffold(
        appBar: GhostHeader(onBack: () => _back(context, ref)),
        body: state.showsEnded
            ? const GhostEndedView()
            : Column(
                children: [
                  Expanded(child: _Timeline(state: state)),
                  GhostComposer(enabled: state.canSend),
                ],
              ),
      ),
    );
  }
}

class _Timeline extends ConsumerWidget {
  const _Timeline({required this.state});

  final GhostState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = state.items.reversed.toList();
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: items.length + 1,
      itemBuilder: (context, index) {
        if (index == items.length) return const _Banner();
        // The list is reversed, so `index + 1` is the OLDER neighbour.
        final item = items[index];
        return GhostBubble(
          key: ValueKey(item.id),
          item: item,
          position: ghostClusterPosition(
            index + 1 < items.length ? items[index + 1] : null,
            item,
            index > 0 ? items[index - 1] : null,
          ),
        );
      },
    );
  }
}

class _Banner extends ConsumerWidget {
  const _Banner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            ChatIcon(
              HugeIcons.strokeRoundedLockKey,
              size: 20,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                ghostText(ref, 'ghost_banner'),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
