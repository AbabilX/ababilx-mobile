import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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
    final progress = historyRestoreLabel(
      (key) => AppTranslations.translate(context, ref, key),
      restore,
    );
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

/// Messages, never chats: "1,234 / 5,678" once the server has counted, the
/// running number before that (or against an older server). A message that
/// arrives mid-restore can push the count past the total, so the total grows
/// with it rather than read "5,679 / 5,678".
String historyRestoreLabel(
  String Function(String key) tr,
  HistoryRestoreState restore,
) {
  final format = NumberFormat.decimalPattern();
  final done = restore.messages;
  final total = restore.messageTotal;
  if (total != null) {
    return tr('history_restore_messages')
        .replaceAll('{done}', format.format(done))
        .replaceAll('{total}', format.format(done > total ? done : total));
  }
  if (done > 0) {
    return tr(
      'history_restore_messages_running',
    ).replaceAll('{done}', format.format(done));
  }
  return tr('history_restore_banner');
}
