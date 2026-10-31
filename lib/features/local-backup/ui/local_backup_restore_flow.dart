import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/widgets/app_toast.dart';
import '../data/backup_pin_store.dart';
import '../local_backup_provider.dart';
import '../platform/backup_folder_channel.dart';
import '../restore/backup_restore_source.dart';
import 'backup_pin_sheet.dart';
import 'restore_pick_sheets.dart';

/// Where is the backup → which one → restore. Used by Settings and by the
/// offer after a recovery-code sign-in or "start fresh".
///
/// [grantBackups] skips the question and opens the system picker on the
/// automatic backup's folder: after a reinstall the files are still there,
/// and one grant is all that stands between them and this install.
Future<void> startLocalBackupRestore(
  BuildContext context,
  WidgetRef ref, {
  bool grantBackups = false,
}) async {
  String tr(String key) => AppTranslations.translate(context, ref, key);
  const folder = BackupFolderChannel();
  final notifier = ref.read(localBackupProvider.notifier);
  final onPhone = grantBackups
      ? const <BackupRestoreSource>[]
      : await notifier.findAutomatic();
  if (!context.mounted) return;
  final source = grantBackups
      ? RestoreSource.folder
      : await pickRestoreSource(context, ref, onPhone: onPhone.isNotEmpty);
  if (source == null || !context.mounted) return;

  var sources = <BackupRestoreSource>[];
  String? pickedFolder;
  try {
    if (source == RestoreSource.phone) {
      sources = onPhone;
    } else if (source == RestoreSource.file) {
      final file = await folder.pickFile();
      if (file != null) {
        sources = [
          BackupRestoreSource(
            main: BackupSourceFile.document(file.uri, file.bytes),
          ),
        ];
      }
    } else {
      final picked = await folder.pickFolder(atBackups: grantBackups);
      if (picked == null || !context.mounted) return;
      pickedFolder = picked.uri;
      final userId = await notifier.currentUser();
      final found = await readGrantedFolder(folder, picked.uri, userId);
      if (!context.mounted) return;
      final mine = found.entries.where((e) => e.owner == userId).toList();
      if (found.accountLayout && mine.isNotEmpty) {
        // The automatic backup's own layout: the newest is the one.
        sources = mine.map(found.sourceFor).toList();
      } else {
        final entry = await pickBackupEntry(
          context,
          ref,
          entries: found.entries,
          userId: userId,
        );
        if (entry != null) sources = [found.sourceFor(entry)];
      }
    }
  } catch (_) {
    if (context.mounted) {
      showAppToast(context, tr('local_backup_error_folder_io'), isError: true);
    }
    return;
  }
  if (sources.isEmpty || !context.mounted) return;
  final container = ProviderScope.containerOf(context, listen: false);
  await runLocalBackupRestore(context, sources);

  // A folder picked only to restore from is given back; the backup folder
  // proper keeps its grant for the scheduled run.
  if (pickedFolder != null &&
      pickedFolder != container.read(localBackupProvider).settings.folderUri) {
    await folder.releaseFolder(pickedFolder).catchError((_) {});
  }
}

/// The reference app's way: the restore runs behind the chat list, shown by the
/// banner there (LocalBackupRestoreBanner), and the app stays usable. Returns
/// the failure key, or null when the backup came back.
///
/// The screen that started it may be gone by the end, and its ref with it —
/// so the provider container and the root navigator's context are taken
/// before anything is awaited.
Future<String?> runLocalBackupRestore(
  BuildContext context,
  List<BackupRestoreSource> sources, {
  bool openChats = true,
}) async {
  final root = Navigator.of(context, rootNavigator: true).context;
  final container = ProviderScope.containerOf(context, listen: false);
  final lang = container.read(appLanguageProvider);
  final notifier = container.read(localBackupProvider.notifier);
  final run = notifier.restoreFirst(sources);
  if (openChats) GoRouter.of(context).go('/messages');
  var (stats, error) = await run;
  // A PIN backup this install has no key for: the PIN alone opens it. The
  // key is kept only once it has opened the backup.
  String? wrong;
  while (error == 'local_backup_error_needs_pin') {
    if (!root.mounted) break;
    final pin = await showBackupPinSheet(root, confirm: false, error: wrong);
    if (pin == null) break;
    final userId = await notifier.currentUser();
    final key = await BackupPinStore.derive(userId, pin);
    (stats, error) = await notifier.restoreFirst(sources, pinKey: key);
    if (error == null) {
      await container.read(backupPinStoreProvider).save(userId, key);
    }
    wrong = AppTranslations.of(lang, 'backup_pin_wrong');
  }
  if (!root.mounted) return error;
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
  return error;
}
