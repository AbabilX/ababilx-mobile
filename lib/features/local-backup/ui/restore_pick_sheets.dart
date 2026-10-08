import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../../messages/chat_icon.dart';
import '../platform/backup_folder_channel.dart';
import 'local_backup_labels.dart';

enum RestoreSource { phone, folder, file }

/// Folder first: it is where the daily backups are, and picking it also shows
/// both of them. A single file is for a backup carried over from another
/// phone, which can sit anywhere.
///
/// [onPhone]: the automatic backup is readable right here, so it is offered
/// first and needs no picking at all.
Future<RestoreSource?> pickRestoreSource(
  BuildContext context,
  WidgetRef ref, {
  bool onPhone = false,
}) {
  String tr(String key) => AppTranslations.translate(context, ref, key);
  return showModalBottomSheet<RestoreSource>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    builder: (sheet) {
      final text = Theme.of(sheet).textTheme;
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                tr('local_backup_restore_source_title'),
                style: text.titleLarge,
              ),
            ),
            if (onPhone)
              ListTile(
                leading: const ChatIcon(HugeIcons.strokeRoundedSmartPhone01),
                title: Text(tr('local_backup_restore_from_phone')),
                onTap: () => Navigator.of(sheet).pop(RestoreSource.phone),
              ),
            ListTile(
              leading: const ChatIcon(HugeIcons.strokeRoundedFolderOpen),
              title: Text(tr('local_backup_restore_from_folder')),
              onTap: () => Navigator.of(sheet).pop(RestoreSource.folder),
            ),
            ListTile(
              leading: const ChatIcon(HugeIcons.strokeRoundedFileImport),
              title: Text(tr('local_backup_restore_from_file')),
              onTap: () => Navigator.of(sheet).pop(RestoreSource.file),
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

/// The backups in a folder, newest first. Another account's files are shown
/// but cannot be picked — hiding them would read as "your backup is gone".
Future<BackupFolderEntry?> pickBackupEntry(
  BuildContext context,
  WidgetRef ref, {
  required List<BackupFolderEntry> entries,
  required String userId,
}) {
  String tr(String key) => AppTranslations.translate(context, ref, key);
  final now = DateTime.now();
  return showModalBottomSheet<BackupFolderEntry>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheet) {
      final theme = Theme.of(sheet);
      final muted = theme.colorScheme.onSurfaceVariant;
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheet).height * 0.7,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  tr('local_backup_restore_pick_title'),
                  style: theme.textTheme.titleLarge,
                ),
              ),
              if (entries.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    tr('local_backup_restore_empty'),
                    style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                  ),
                ),
              for (final entry in entries)
                _EntryTile(
                  entry: entry,
                  mine: entry.owner == userId,
                  when: backupTimeLabel(
                    DateTime.fromMillisecondsSinceEpoch(entry.modifiedMs),
                    now: now,
                    today: tr('local_backup_today'),
                    yesterday: tr('local_backup_yesterday'),
                  ),
                  otherAccount: tr('local_backup_other_account'),
                  onTap: () => Navigator.of(sheet).pop(entry),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    },
  );
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({
    required this.entry,
    required this.mine,
    required this.when,
    required this.otherAccount,
    required this.onTap,
  });

  final BackupFolderEntry entry;
  final bool mine;
  final String when;
  final String otherAccount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final size = backupSizeLabel(entry.bytes);
    return ListTile(
      enabled: mine,
      leading: const ChatIcon(HugeIcons.strokeRoundedDatabaseRestore),
      title: Text(when),
      subtitle: Text(mine ? size : '$size · $otherAccount'),
      onTap: mine ? onTap : null,
    );
  }
}
