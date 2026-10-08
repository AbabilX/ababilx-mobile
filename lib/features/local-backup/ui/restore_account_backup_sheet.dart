import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../restore/backup_restore_source.dart';
import 'local_backup_labels.dart';

/// "Backup from Today 3:12 AM · 1.2 GB", or the size alone when the folder
/// did not say when the file was written.
String accountBackupLabel(
  BackupRestoreSource source,
  String Function(String) tr,
) {
  final size = backupSizeLabel(source.bytes);
  final at = source.createdAtMs;
  if (at == null || at <= 0) return size;
  final when = backupTimeLabel(
    DateTime.fromMillisecondsSinceEpoch(at),
    now: DateTime.now(),
    today: tr('local_backup_today'),
    yesterday: tr('local_backup_yesterday'),
  );
  return tr(
    'restore_backup_label',
  ).replaceAll('{when}', when).replaceAll('{size}', size);
}

/// Asked before the account gets a new message key. It states what is lost
/// first: the step after this one cannot be taken back.
Future<bool> confirmContinueWithBackup(
  BuildContext context,
  WidgetRef ref,
  BackupRestoreSource source,
) async {
  String tr(String key) => AppTranslations.translate(context, ref, key);
  final go = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheet) {
      final theme = Theme.of(sheet);
      final muted = theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      );
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                tr('restore_backup_confirm_title'),
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(accountBackupLabel(source, tr), style: muted),
              const SizedBox(height: 12),
              Text(tr('restore_backup_confirm_body'), style: muted),
              const SizedBox(height: 20),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: () => Navigator.of(sheet).pop(true),
                child: Text(tr('restore_backup_confirm_go')),
              ),
              const SizedBox(height: 8),
              TextButton(
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: () => Navigator.of(sheet).pop(false),
                child: Text(tr('cancel')),
              ),
            ],
          ),
        ),
      );
    },
  );
  return go == true;
}
