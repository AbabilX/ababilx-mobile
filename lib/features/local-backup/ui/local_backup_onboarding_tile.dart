import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../messages/chat_icon.dart';
import '../data/local_backup_settings.dart';
import '../local_backup_provider.dart';

/// The backup row on the first-run screen: on unless the person says
/// otherwise, with the folder as an option rather than a step.
///
/// Drawn like the permission rows above it (48dp picture, title, why). It
/// says in one line what the copy is and that it is not end-to-end — a
/// default nobody was told about is not a default they agreed to.
class LocalBackupOnboardingTile extends ConsumerWidget {
  const LocalBackupOnboardingTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!LocalBackupSettingsStore.automatic) return const SizedBox.shrink();
    final state = ref.watch(localBackupProvider);
    if (!state.loaded) return const SizedBox.shrink();
    String t(String key) => AppTranslations.translate(context, ref, key);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final settings = state.settings;
    final notifier = ref.read(localBackupProvider.notifier);

    Future<void> chooseFolder() async {
      final error = await notifier.changeFolder();
      if (error != null && context.mounted) {
        showAppToast(context, t(error), isError: true);
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ChatIcon(
            HugeIcons.strokeRoundedDatabaseSync,
            size: 48,
            color: colors.primary,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('local_backup_onboarding_title'),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colors.onSurface,
                  ),
                ),
                Text(
                  t('local_backup_onboarding_body'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                if (settings.enabled)
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 40),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: chooseFolder,
                    child: Text(
                      settings.hasFolder
                          ? t(
                              'local_backup_onboarding_folder',
                            ).replaceAll('{name}', settings.folderLabel ?? '—')
                          : t('local_backup_choose_folder'),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(value: settings.enabled, onChanged: notifier.setEnabled),
        ],
      ),
    );
  }
}
