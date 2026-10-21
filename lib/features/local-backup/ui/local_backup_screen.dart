import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/widgets/app_bar_back_button.dart';
import '../../settings/settings-hub/settings_row.dart';
import '../local_backup_provider.dart';
import 'local_backup_actions.dart';
import 'local_backup_choice_rows.dart';
import 'local_backup_delivery_notice.dart';
import 'local_backup_labels.dart';
import 'local_backup_requirements.dart';
import 'local_backup_restore_flow.dart';

/// Settings → Backup → Local backup. The switch, where and when the last
/// backup went, what goes in, and the way back.
class LocalBackupScreen extends ConsumerWidget {
  const LocalBackupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String t(String key) => AppTranslations.translate(context, ref, key);
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final state = ref.watch(localBackupProvider);
    final s = state.settings;

    final actions = LocalBackupActions(context, ref);

    final last = s.lastBackupMs == null
        ? t('local_backup_never')
        : [
            backupTimeLabel(
              DateTime.fromMillisecondsSinceEpoch(s.lastBackupMs!),
              now: DateTime.now(),
              today: t('local_backup_today'),
              yesterday: t('local_backup_yesterday'),
            ),
            if (s.lastBackupBytes != null) backupSizeLabel(s.lastBackupBytes!),
          ].join(' · ');

    return Scaffold(
      appBar: AppBar(
        leading: const AppBarBackButton(),
        title: Text(t('local_backup_title')),
      ),
      body: !state.loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                LocalBackupDeliveryNotice(backupOn: s.enabled),
                SwitchListTile(
                  value: s.enabled,
                  onChanged: state.busy ? null : actions.toggle,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  title: Text(
                    t('local_backup_title'),
                    style: theme.textTheme.titleSmall,
                  ),
                  subtitle: Text(
                    t('local_backup_switch_hint'),
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                ),
                if (s.enabled) ...[
                  const LocalBackupRequirements(),
                  SettingsRow(
                    icon: HugeIcons.strokeRoundedFolder01,
                    title: t('local_backup_folder'),
                    value: s.hasFolder
                        ? (s.folderLabel ?? '—')
                        : t('local_backup_folder_phone'),
                    onTap: state.busy ? null : actions.changeFolder,
                  ),
                  SettingsRow(
                    icon: HugeIcons.strokeRoundedDatabaseSync,
                    title: t('local_backup_last'),
                    subtitle: s.lastFailureKey == null
                        ? null
                        : t(s.lastFailureKey!),
                    value: last,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: state.phase == LocalBackupPhase.backingUp
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              LinearProgressIndicator(
                                value: state.progressTotal > 0
                                    ? (state.progress / state.progressTotal)
                                          .clamp(0.0, 1.0)
                                    : null,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _runningLabel(t, state),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: muted,
                                ),
                              ),
                            ],
                          )
                        : FilledButton.tonal(
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(44),
                            ),
                            onPressed: state.busy ? null : actions.backUpNow,
                            child: Text(t('local_backup_now')),
                          ),
                  ),
                ],
                const Divider(height: 32),
                const LocalBackupChoiceRows(),
                const Divider(height: 32),
                SettingsRow(
                  icon: HugeIcons.strokeRoundedDatabaseRestore,
                  title: t('local_backup_restore'),
                  subtitle: t('local_backup_restore_hint'),
                  onTap: state.busy
                      ? null
                      : () => startLocalBackupRestore(context, ref),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Text(
                    t('local_backup_security_note'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: muted,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

/// "Saving changes… 120 of 480 messages" once the changed weeks are known,
/// "Backing up… 2 400 messages" while the backup is still counting.
String _runningLabel(String Function(String) t, LocalBackupState state) =>
    state.progressTotal > 0
    // A message arriving mid-run can be sealed beyond the count taken first.
    ? t('local_backup_sealing')
          .replaceAll('{n}', '${state.progress.clamp(0, state.progressTotal)}')
          .replaceAll('{total}', '${state.progressTotal}')
    : t('local_backup_running').replaceAll('{n}', '${state.progress}');
