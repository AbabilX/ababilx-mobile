import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/widgets/app_bar_back_button.dart';
import '../../messages/chat_icon.dart';
import '../../settings/settings-hub/settings_row.dart';
import '../import/chat_import_store.dart';
import 'imported_time.dart';

/// Every imported zip, its chats under it. Read-only: tapping a chat opens
/// its messages, the bin removes that import from this phone.
class ImportedArchivesScreen extends ConsumerWidget {
  const ImportedArchivesScreen({super.key});

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    ImportedArchive archive,
  ) async {
    String t(String key) => AppTranslations.translate(context, ref, key);
    final yes = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheet) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              t('chat_imported_delete_title'),
              style: Theme.of(sheet).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(sheet).colorScheme.error,
                foregroundColor: Theme.of(sheet).colorScheme.onError,
              ),
              onPressed: () => Navigator.pop(sheet, true),
              child: Text(t('chat_imported_delete')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(sheet, false),
              child: Text(t('cancel')),
            ),
          ],
        ),
      ),
    );
    if (yes != true) return;
    await ref.read(chatImportStoreProvider).delete(archive);
    ref.invalidate(importedArchivesProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String t(String key) => AppTranslations.translate(context, ref, key);
    final theme = Theme.of(context);
    final archives = ref.watch(importedArchivesProvider);
    return Scaffold(
      appBar: AppBar(
        leading: const AppBarBackButton(),
        title: Text(t('chat_imported_title')),
      ),
      body: archives.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(child: Text(t('chat_import_error_unreadable'))),
        data: (list) => list.isEmpty
            ? Center(child: Text(t('chat_imported_empty')))
            : ListView(
                padding: const EdgeInsets.only(bottom: 32),
                children: [
                  for (final a in list) ...[
                    ListTile(
                      contentPadding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
                      title: Text(
                        a.manifest.accountName,
                        style: theme.textTheme.titleSmall,
                      ),
                      subtitle: Text(
                        t('chat_imported_from').replaceAll(
                          '{date}',
                          importedDate(a.manifest.exportedAt),
                        ),
                      ),
                      trailing: IconButton(
                        tooltip: t('chat_imported_delete'),
                        onPressed: () => _delete(context, ref, a),
                        icon: ChatIcon(
                          HugeIcons.strokeRoundedDelete02,
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                    for (final c in a.manifest.chats)
                      SettingsRow(
                        icon: c.kind == 'group'
                            ? HugeIcons.strokeRoundedUserGroup
                            : HugeIcons.strokeRoundedUser,
                        title: c.title,
                        subtitle: t(
                          'chat_imported_count',
                        ).replaceAll('{n}', '${c.messages}'),
                        value: importedDate(c.lastAt),
                        onTap: () => context.push(
                          '/settings/chat-backup/imported/${a.id}/'
                          '${Uri.encodeComponent(c.folder)}',
                        ),
                      ),
                    const Divider(height: 24),
                  ],
                ],
              ),
      ),
    );
  }
}
