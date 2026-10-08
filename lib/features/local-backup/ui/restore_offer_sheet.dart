import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import 'local_backup_labels.dart';

/// "Restore from a backup?" — asked once. With [foundAtMs] the backup is
/// already readable on this phone and the sheet says when it was made;
/// without it, Restore leads to granting the backup folder.
Future<bool> askRestoreFromBackup(
  BuildContext context,
  WidgetRef ref, {
  int? foundAtMs,
}) async {
  String tr(String key) => AppTranslations.translate(context, ref, key);
  final body = foundAtMs == null
      ? tr('local_backup_restore_offer_body')
      : tr('local_backup_restore_found_body').replaceAll(
          '{when}',
          backupTimeLabel(
            DateTime.fromMillisecondsSinceEpoch(foundAtMs),
            now: DateTime.now(),
            today: tr('local_backup_today'),
            yesterday: tr('local_backup_yesterday'),
          ),
        );
  final go = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    builder: (sheet) {
      final theme = Theme.of(sheet);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                tr('local_backup_restore_offer_title'),
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                body,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: () => Navigator.of(sheet).pop(true),
                child: Text(tr('local_backup_restore_now')),
              ),
              const SizedBox(height: 8),
              TextButton(
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: () => Navigator.of(sheet).pop(false),
                child: Text(tr('local_backup_not_now')),
              ),
            ],
          ),
        ),
      );
    },
  );
  return go == true;
}
