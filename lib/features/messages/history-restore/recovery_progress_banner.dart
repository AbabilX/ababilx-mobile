import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_translations.dart';
import '../archive/archive_provider.dart';
import '../providers/chat_provider.dart';
import 'history_restore_state.dart';
import 'history_restore_banner.dart';

class RecoveryProgressBanner extends ConsumerWidget {
  const RecoveryProgressBanner({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final archive = ref.watch(archiveProvider);
    final history = ref.watch(historyRestoreProvider);
    if (archive.phase != ArchivePhase.restoring &&
        archive.error.isEmpty &&
        !history.failed) {
      return const HistoryRestoreBanner();
    }
    final failed = archive.error.isNotEmpty || history.failed;
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerLow,
      child: ListTile(
        dense: true,
        leading: failed
            ? const Icon(Icons.refresh)
            : const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
        title: Text(
          AppTranslations.translate(
            context,
            ref,
            failed ? 'recovery_restore_failed' : 'history_restore_banner',
          ),
        ),
        onTap: failed
            ? () async {
                await ref.read(archiveProvider.notifier).restoreAfterRecovery();
                await ref
                    .read(chatProvider.notifier)
                    .markHistoryRestorePending();
                await ref
                    .read(chatProvider.notifier)
                    .startHistoryRestoreIfNeeded();
              }
            : null,
      ),
    );
  }
}
