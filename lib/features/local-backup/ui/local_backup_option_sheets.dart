import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../../messages/chat_icon.dart';

enum BackupFolderChoice { phone, pick }

enum BackupOffChoice { keep, delete }

Future<T?> _options<T>(
  BuildContext context, {
  required String title,
  String? body,
  required List<(T, List<List<dynamic>>, String, bool)> rows,
}) => showModalBottomSheet<T>(
  context: context,
  useRootNavigator: true,
  showDragHandle: true,
  builder: (sheet) {
    final theme = Theme.of(sheet);
    final colors = theme.colorScheme;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(title, style: theme.textTheme.titleLarge),
          ),
          if (body != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                body,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          for (final (value, icon, label, danger) in rows)
            ListTile(
              leading: ChatIcon(icon, color: danger ? colors.error : null),
              title: Text(
                label,
                style: danger ? TextStyle(color: colors.error) : null,
              ),
              onTap: () => Navigator.of(sheet).pop(value),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  },
);

/// Where the backup goes: the automatic folder, or one the person picks.
Future<BackupFolderChoice?> pickBackupFolderChoice(
  BuildContext context,
  WidgetRef ref,
) {
  String tr(String key) => AppTranslations.translate(context, ref, key);
  return _options(
    context,
    title: tr('local_backup_folder'),
    body: tr('local_backup_folder_sheet_body'),
    rows: [
      (
        BackupFolderChoice.phone,
        HugeIcons.strokeRoundedSmartPhone01,
        tr('local_backup_folder_phone'),
        false,
      ),
      (
        BackupFolderChoice.pick,
        HugeIcons.strokeRoundedFolderOpen,
        tr('local_backup_choose_folder'),
        false,
      ),
    ],
  );
}

/// Turning the automatic backup off: keep what is on the phone, or remove
/// it. Null when the sheet was dismissed, which changes nothing.
Future<BackupOffChoice?> pickBackupOffChoice(
  BuildContext context,
  WidgetRef ref,
) {
  String tr(String key) => AppTranslations.translate(context, ref, key);
  return _options(
    context,
    title: tr('local_backup_off_title'),
    body: tr('local_backup_off_body'),
    rows: [
      (
        BackupOffChoice.keep,
        HugeIcons.strokeRoundedDatabase,
        tr('local_backup_off_keep'),
        false,
      ),
      (
        BackupOffChoice.delete,
        HugeIcons.strokeRoundedDelete02,
        tr('local_backup_off_delete'),
        true,
      ),
    ],
  );
}
