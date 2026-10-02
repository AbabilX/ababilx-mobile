import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

  // Signal's way: the restore runs behind the chat list, shown by the
  // banner there (LocalBackupRestoreBanner), and the app stays usable. The
  // root navigator's context outlives the screen that started it, so the
  // last word still has somewhere to land.
  // The screen that started it may be gone by the end, and its ref with it.
  final root = Navigator.of(context, rootNavigator: true).context;
  final container = ProviderScope.containerOf(context, listen: false);
  final lang = container.read(appLanguageProvider);
  final run = container.read(localBackupProvider.notifier).restore(documentUri);
  GoRouter.of(context).go('/messages');
  final (stats, error) = await run;

  // A folder picked only to restore from is given back; the backup folder
  // proper keeps its grant for the daily run.
  if (pickedFolder != null &&
      pickedFolder != container.read(localBackupProvider).settings.folderUri) {
    await folder.releaseFolder(pickedFolder).catchError((_) {});
  }
  if (!root.mounted) return;
  if (stats != null) {
    showAppToast(
      root,
      AppTranslations.of(
        lang,
        'local_backup_restored',
      ).replaceAll('{n}', '${stats.messages}'),
    );
  } else if (error != 'local_backup_error_cancelled') {
    showAppToast(
      root,
      AppTranslations.of(lang, error ?? 'local_backup_error_generic'),
      isError: true,
    );
  }
}
