import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import 'history_restore_state.dart';

/// Thin list-header line while recovery is pulling the newest page of every
/// chat. Not a blocker — the list stays usable underneath.
class HistoryRestoreBanner extends ConsumerWidget {
  const HistoryRestoreBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final restore = ref.watch(historyRestoreProvider);
    if (!restore.running) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    final label = AppTranslations.translate(
      context,
      ref,
      'history_restore_banner',
    );
    final progress = restore.total > 0
        ? '$label  ${restore.done}/${restore.total}'
        : label;
    return Material(
      color: colors.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colors.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                progress,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
