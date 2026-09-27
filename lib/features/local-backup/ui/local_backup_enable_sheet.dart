import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../../messages/chat_icon.dart';

/// The one time the trade is spelled out, before the folder picker opens.
///
/// It has to say the uncomfortable part plainly: this file is not end-to-end
/// encrypted. The key is on our server and the file is on the phone, and a
/// person choosing a backup that survives a lost recovery code is choosing
/// exactly that. Answers true only when "Choose folder" was pressed.
Future<bool> confirmEnableLocalBackup(
  BuildContext context,
  WidgetRef ref,
) async {
  String tr(String key) => AppTranslations.translate(context, ref, key);
  final go = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheet) {
      final colors = Theme.of(sheet).colorScheme;
      final text = Theme.of(sheet).textTheme;
      Widget point(List<List<dynamic>> icon, String key) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ChatIcon(icon, size: 20, color: colors.primary),
            const SizedBox(width: 12),
            Expanded(child: Text(tr(key), style: text.bodyMedium)),
          ],
        ),
      );
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(tr('local_backup_enable_title'), style: text.titleLarge),
              const SizedBox(height: 16),
              point(
                HugeIcons.strokeRoundedFolder01,
                'local_backup_enable_point_daily',
              ),
              point(
                HugeIcons.strokeRoundedUser,
                'local_backup_enable_point_account',
              ),
              point(
                HugeIcons.strokeRoundedLockKey,
                'local_backup_enable_point_key',
              ),
              point(
                HugeIcons.strokeRoundedFolderOpen,
                'local_backup_enable_point_folder',
              ),
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: () => Navigator.of(sheet).pop(true),
                child: Text(tr('local_backup_choose_folder')),
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
