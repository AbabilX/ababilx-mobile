import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../messages/chat_icon.dart';
import '../quick-views/quick_view_summary.dart';
import 'catch_up_queue.dart';

/// Keep Unread · Mark as Read — twin actions under the deck, theme + HugeIcons.
class CatchUpBar extends ConsumerWidget {
  const CatchUpBar({super.key, required this.onStep, this.enabled = true});

  final ValueChanged<CatchUpStep> onStep;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Row(
          children: [
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: enabled
                    ? () => onStep(CatchUpStep.keptUnread)
                    : null,
                icon: ChatIcon(
                  HugeIcons.strokeRoundedMail01,
                  size: 20,
                  color: colors.onSecondaryContainer,
                ),
                label: Text(homeText(context, ref, 'home_catch_up_keep')),
                style: FilledButton.styleFrom(
                  backgroundColor: colors.secondaryContainer,
                  foregroundColor: colors.onSecondaryContainer,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: enabled
                    ? () => onStep(CatchUpStep.markedRead)
                    : null,
                icon: ChatIcon(
                  HugeIcons.strokeRoundedTick02,
                  size: 20,
                  color: colors.onPrimary,
                ),
                label: Text(homeText(context, ref, 'home_catch_up_mark')),
                style: FilledButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
