import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../settings/settings-hub/settings_row.dart';
import '../../settings/settings-hub/settings_section_header.dart';
import '../export/chat_export_runner.dart';
import '../import/chat_import_store.dart';
import '../import/chat_import_unzip.dart';
import 'chat_export_sheets.dart';

/// Messages read so far while an export runs; null when none is running.
final chatExportProgressProvider = StateProvider<int?>((_) => null);

/// Imports running (a picker copy can be large); blocks a second tap.
final chatImportBusyProvider = StateProvider<bool>((_) => false);

final chatExportRunnerProvider = Provider<ChatExportRunner>(
  (ref) => ChatExportRunner(ref),
);

/// Settings → Backup → Export chats: one plain zip of every chat, import a
/// zip, and the chats imported so far.
class ChatExportSection extends ConsumerWidget {
  const ChatExportSection({super.key});

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    String t(String key) => AppTranslations.translate(context, ref, key);
    if (!await confirmChatExport(context, ref)) return;
    final progress = ref.read(chatExportProgressProvider.notifier);
    progress.state = 0;
    try {
      final result = await ref
          .read(chatExportRunnerProvider)
          .run(onProgress: (n) => progress.state = n);
      if (context.mounted) await showChatExportDone(context, ref, result);
    } on ChatExportFailure catch (e) {
      if (context.mounted) {
        showAppToast(context, t(e.messageKey), isError: true);
      }
    } catch (e) {
      debugPrint('[ChatExport] failed: $e');
      if (context.mounted) {
        showAppToast(context, t('chat_export_error'), isError: true);
      }
    } finally {
      progress.state = null;
    }
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    String t(String key) => AppTranslations.translate(context, ref, key);
    // The screen may close while the picker or the unzip runs.
    final container = ProviderScope.containerOf(context, listen: false);
    final busy = container.read(chatImportBusyProvider.notifier);
    busy.state = true;
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['zip'],
      );
      final path = picked?.files.single.path;
      if (path == null) return;
      final archive = await container
          .read(chatImportStoreProvider)
          .import(path);
      container.invalidate(importedArchivesProvider);
      if (!context.mounted) return;
      showAppToast(
        context,
        t('chat_import_done')
            .replaceAll('{chats}', '${archive.manifest.chats.length}')
            .replaceAll('{messages}', '${archive.manifest.messages}'),
      );
      context.push('/settings/chat-backup/imported');
    } on ChatImportFailure catch (e) {
      if (context.mounted) {
        showAppToast(context, t(e.messageKey), isError: true);
      }
    } catch (e) {
      debugPrint('[ChatImport] failed: $e');
      if (context.mounted) {
        showAppToast(context, t('chat_import_error_unreadable'), isError: true);
      }
    } finally {
      busy.state = false;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String t(String key) => AppTranslations.translate(context, ref, key);
    final progress = ref.watch(chatExportProgressProvider);
    final importing = ref.watch(chatImportBusyProvider);
    final imported = ref.watch(importedArchivesProvider).valueOrNull ?? [];
    final chats = imported.fold<int>(0, (n, a) => n + a.manifest.chats.length);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsSectionHeader(t('chat_export_section')),
        SettingsRow(
          icon: HugeIcons.strokeRoundedFileZip,
          title: t('chat_export_title'),
          subtitle: progress == null
              ? t('chat_export_hint')
              : t('chat_export_running').replaceAll('{n}', '$progress'),
          onTap: progress == null ? () => _export(context, ref) : null,
        ),
        SettingsRow(
          icon: HugeIcons.strokeRoundedFileImport,
          title: t('chat_import_title'),
          subtitle: t(importing ? 'chat_import_running' : 'chat_import_hint'),
          onTap: importing ? null : () => _import(context, ref),
        ),
        if (imported.isNotEmpty)
          SettingsRow(
            icon: HugeIcons.strokeRoundedArchive02,
            title: t('chat_imported_title'),
            value: '$chats',
            onTap: () => context.push('/settings/chat-backup/imported'),
          ),
      ],
    );
  }
}
