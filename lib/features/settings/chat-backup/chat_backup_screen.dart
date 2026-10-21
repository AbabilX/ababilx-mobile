import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/widgets/app_bar_back_button.dart';
import '../../messages/chat_icon.dart';
import '../../chat-export/ui/chat_export_section.dart';
import '../settings-hub/settings_row.dart';
import '../settings-hub/settings_section_header.dart';

/// Settings → Backup: where the chats live (the phone — the server deletes a
/// message once every phone has it, DELIVERY_ONLY.md) and the local backup
/// that is their only lasting copy. No recovery code: a new install starts a
/// new message key and gets its history from the local backup.
class ChatBackupScreen extends ConsumerWidget {
  const ChatBackupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String t(String key) => AppTranslations.translate(context, ref, key);

    return Scaffold(
      appBar: AppBar(
        leading: const AppBarBackButton(),
        title: Text(t('settings_backup')),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            SettingsSectionHeader(t('backup_section_recent')),
            _RecentRetentionNotice(
              title: t('backup_recent_title'),
              body: t('backup_recent_body'),
            ),
            const Divider(height: 24),
            SettingsSectionHeader(t('local_backup_section')),
            SettingsRow(
              icon: HugeIcons.strokeRoundedFolder01,
              title: t('local_backup_title'),
              subtitle: t('local_backup_row_hint'),
              onTap: () => context.push('/settings/chat-backup/local'),
            ),
            const Divider(height: 24),
            const ChatExportSection(),
          ],
        ),
      ),
    );
  }
}

class _RecentRetentionNotice extends StatelessWidget {
  const _RecentRetentionNotice({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: ChatIcon(
              HugeIcons.strokeRoundedSmartPhone01,
              size: 22,
              color: colors.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: text.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
