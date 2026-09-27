import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../messages/providers/chat_provider.dart';
import '../local_backup_provider.dart';
import '../platform/backup_folder_channel.dart';
import 'restore_pick_sheets.dart';

/// Where is the backup → which one → restore, with a count while it runs and
/// one sentence at the end. Used by Settings and by the one-time offer after
/// a recovery-code sign-in or "start fresh".
Future<void> startLocalBackupRestore(
  BuildContext context,
  WidgetRef ref,
) async {
  String tr(String key) => AppTranslations.translate(context, ref, key);
  const folder = BackupFolderChannel();
  final source = await pickRestoreSource(context, ref);
  if (source == null || !context.mounted) return;

  String? documentUri;
  String? pickedFolder;
  try {
    if (source == RestoreSource.file) {
      documentUri = (await folder.pickFile())?.uri;
    } else {
      final picked = await folder.pickFolder();
      if (picked == null || !context.mounted) return;
      pickedFolder = picked.uri;
      final userId = await ref
          .read(chatProvider.notifier)
          .ensureCurrentUserId();
      final entries = await folder.list(picked.uri);
      if (!context.mounted) return;
      final entry = await pickBackupEntry(
        context,
        ref,
        entries: entries,
        userId: userId,
      );
      documentUri = entry?.uri;
    }
  } catch (_) {
    if (context.mounted) {
      showAppToast(context, tr('local_backup_error_folder_io'), isError: true);
    }
    return;
  }
  if (documentUri == null || !context.mounted) return;

  final notifier = ref.read(localBackupProvider.notifier);
  final run = notifier.restore(documentUri);
  final navigator = Navigator.of(context, rootNavigator: true);
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isDismissible: false,
    enableDrag: false,
    builder: (_) => PopScope(
      canPop: false,
      child: _RestoreProgress(onCancel: notifier.cancel),
    ),
  );
  final (stats, error) = await run;
  navigator.pop();

  // A folder picked only to restore from is given back; the backup folder
  // proper keeps its grant for the daily run.
  if (pickedFolder != null &&
      pickedFolder != ref.read(localBackupProvider).settings.folderUri) {
    await folder.releaseFolder(pickedFolder).catchError((_) {});
  }
  if (!context.mounted) return;
  if (stats != null) {
    showAppToast(
      context,
      tr('local_backup_restored').replaceAll('{n}', '${stats.messages}'),
    );
  } else if (error != 'local_backup_error_cancelled') {
    showAppToast(
      context,
      tr(error ?? 'local_backup_error_generic'),
      isError: true,
    );
  }
}

class _RestoreProgress extends ConsumerWidget {
  const _RestoreProgress({required this.onCancel});

  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String tr(String key) => AppTranslations.translate(context, ref, key);
    final theme = Theme.of(context);
    final count = ref.watch(localBackupProvider.select((s) => s.progress));
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const LinearProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              tr('local_backup_restoring').replaceAll('{n}', '$count'),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              tr('local_backup_restore_keep_open'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: onCancel, child: Text(tr('cancel'))),
          ],
        ),
      ),
    );
  }
}
