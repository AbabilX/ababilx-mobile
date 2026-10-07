import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/widgets/app_bar_back_button.dart';
import '../../chat-lock/providers/chat_locks_provider.dart';
import '../../chat-lock/widgets/chat_lock_actions.dart';
import '../../messages/chat_icon.dart';
import '../settings-hub/settings_row.dart';
import '../settings-hub/settings_section_header.dart';

/// Settings → Data and storage → Chat lock.
///
/// One action: prove the phone's own lock (fingerprint, face or system PIN),
/// then drop every chat lock so those chats sit in the ordinary list again.
class ChatLockSettingsScreen extends ConsumerWidget {
  const ChatLockSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String t(String key) => AppTranslations.translate(context, ref, key);
    final count = ref.watch(chatLocksProvider.select((m) => m.length));
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        leading: const AppBarBackButton(),
        title: Text(t('chatlock_settings_title')),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            SettingsSectionHeader(t('chatlock_settings_section')),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                t('chatlock_settings_body'),
                style: text.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
            ),
            SettingsRow(
              icon: HugeIcons.strokeRoundedFingerPrint,
              title: t('chatlock_reset_all'),
              subtitle: count == 0
                  ? t('chatlock_reset_all_none')
                  : t('chatlock_reset_all_sub').replaceAll('{count}', '$count'),
              onTap: count == 0 ? null : () => resetAllChatLocks(context, ref),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ChatIcon(
                    HugeIcons.strokeRoundedInformationCircle,
                    size: 18,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      t('chatlock_reset_all_footnote'),
                      style: text.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
