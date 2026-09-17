import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../messages/chat_icon.dart';
import '../providers/ghost_provider.dart';
import '../providers/ghost_state.dart';
import 'ghost_labels.dart';

/// What is left after a burn: a flame, who did it, and a way out. The flame
/// scales in once, so the moment reads as something that happened rather than
/// a screen that merely changed.
class GhostEndedView extends ConsumerWidget {
  const GhostEndedView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ghostProvider);
    final theme = Theme.of(context);
    final burned =
        state.endReason == 'burn' ||
        state.endReason == 'leave' ||
        state.endReason == 'lost';
    final error = state.error;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.4, end: 1),
              duration: const Duration(milliseconds: 420),
              curve: Curves.easeOutBack,
              builder: (_, scale, child) =>
                  Transform.scale(scale: scale, child: child),
              child: ChatIcon(
                burned
                    ? HugeIcons.strokeRoundedFire
                    : HugeIcons.strokeRoundedIncognito,
                size: 72,
                strokeWidth: 1.6,
                color: burned
                    ? const Color(0xFFFF5A1F)
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              ghostEndedTitle(ref, state),
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              burned
                  ? ghostText(ref, 'ghost_ended_sub')
                  : error != null
                  ? ghostErrorText(ref, error, name: state.peerName)
                  : '',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            FilledButton.tonal(
              onPressed: ref.read(ghostProvider.notifier).close,
              child: Text(ghostText(ref, 'ghost_close')),
            ),
          ],
        ),
      ),
    );
  }
}

extension GhostEndedPhase on GhostState {
  bool get showsEnded => phase == GhostPhase.ended;
}
