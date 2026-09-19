import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/text/byte_size.dart';
import '../../../shared/widgets/app_bar_back_button.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../messages/archive/archive_provider.dart';
import '../../messages/chat_icon.dart';
import '../../notifications/data/device_identity.dart';
import '../settings-hub/settings_row.dart';
import '../settings-hub/settings_section_header.dart';

/// Settings → Backup: recovery code access and an encrypted message archive.
///
/// The server keeps a rolling copy of recent ciphertext; this screen is for
/// uploading a fuller encrypted archive and restoring it on another device.
/// See CHAT_RETENTION.md.
class ChatBackupScreen extends ConsumerStatefulWidget {
  const ChatBackupScreen({super.key});

  @override
  ConsumerState<ChatBackupScreen> createState() => _ChatBackupScreenState();
}

class _ChatBackupScreenState extends ConsumerState<ChatBackupScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(archiveProvider.notifier).refresh(),
    );
  }

  String _t(String key) =>
      AppTranslations.translate(context, ref, key);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(archiveProvider);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: const AppBarBackButton(),
        title: Text(_t('settings_backup')),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            SettingsSectionHeader(_t('backup_section_recent')),
            _RecentRetentionNotice(
              title: _t('backup_recent_title'),
              body: _t('backup_recent_body'),
            ),
            const Divider(height: 24),
            SettingsSectionHeader(_t('backup_section_recovery')),
            SettingsRow(
              icon: HugeIcons.strokeRoundedKey01,
              title: _t('recovery_codes_title'),
              subtitle: _t('recovery_codes_setting_hint'),
              onTap: () => context.push('/settings/chat-backup/recovery-codes'),
            ),
            const Divider(height: 24),
            SettingsSectionHeader(_t('backup_section_archive')),
            _BackupStatusLine(state: state, translate: _t),
            if (state.error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Text(
                  _errorText(state.error),
                  style: TextStyle(color: colors.error, fontSize: 13),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: FilledButton.icon(
                onPressed: state.busy ? null : () => _backUpNow(),
                icon: ChatIcon(HugeIcons.strokeRoundedCloudUpload, size: 18),
                label: Text(_t('backup_back_up_now')),
              ),
            ),
            if (state.remote != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: OutlinedButton.icon(
                  onPressed: state.busy ? null : () => _restoreNow(),
                  icon: ChatIcon(HugeIcons.strokeRoundedCloudDownload, size: 18),
                  label: Text(_t('backup_restore')),
                ),
              ),
            if (state.remote != null) ...[
              const SizedBox(height: 16),
              SettingsRow(
                icon: HugeIcons.strokeRoundedDatabase01,
                title: _t('backup_stored_size'),
                value: formatBytes(state.remote!.totalBytes),
              ),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Text(
                _t('backup_footnote'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _errorText(String code) => switch (code) {
    'vault_locked' => _t('backup_error_vault_locked'),
    _ => _t('backup_error_network'),
  };

  Future<void> _backUpNow() async {
    final deviceId = await DeviceIdentity.get();
    if (!mounted) return;
    final ok = await ref.read(archiveProvider.notifier).backUp(
      deviceId: deviceId,
      nowMs: DateTime.now().millisecondsSinceEpoch,
    );
    if (!mounted) return;
    showAppToast(
      context,
      ok ? _t('backup_toast_complete') : _t('backup_toast_failed'),
      isError: !ok,
    );
  }

  Future<void> _restoreNow() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t('backup_restore_title')),
        content: Text(_t('backup_restore_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_t('backup_restore')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final restored = await ref.read(archiveProvider.notifier).restore();
    if (!mounted) return;
    showAppToast(
      context,
      restored == null
          ? _t('backup_toast_restore_failed')
          : _t('backup_toast_restored').replaceAll('{n}', '$restored'),
      isError: restored == null,
    );
  }
}

/// Explains automatic 180-day server sync vs the optional archive below.
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
              HugeIcons.strokeRoundedCloud,
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

class _BackupStatusLine extends StatelessWidget {
  const _BackupStatusLine({required this.state, required this.translate});

  final ArchiveState state;
  final String Function(String key) translate;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (state.busy)
            const Padding(
              padding: EdgeInsets.only(top: 3, right: 12),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 12, top: 1),
              child: Icon(
                state.remote == null
                    ? Icons.cloud_off_outlined
                    : Icons.cloud_done_outlined,
                size: 22,
                color: state.remote == null
                    ? colors.onSurfaceVariant
                    : colors.primary,
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_headline(), style: text.titleSmall),
                const SizedBox(height: 2),
                Text(
                  _detail(),
                  style: text.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _headline() => switch (state.phase) {
    ArchivePhase.backingUp => translate('backup_status_backing_up'),
    ArchivePhase.restoring => translate('backup_status_restoring'),
    ArchivePhase.idle => !state.loaded
        ? translate('backup_status_checking')
        : state.remote == null
        ? translate('backup_status_none')
        : translate('backup_status_ready'),
  };

  String _detail() {
    if (state.phase == ArchivePhase.backingUp) {
      return translate('backup_progress_packed')
          .replaceAll('{n}', '${state.progress}');
    }
    if (state.phase == ArchivePhase.restoring) {
      return translate('backup_progress_restored')
          .replaceAll('{n}', '${state.progress}');
    }
    if (!state.loaded) return translate('backup_status_checking');
    if (state.remote == null) return translate('backup_detail_none');
    final last = state.lastBackupAt;
    if (last == null) return translate('backup_detail_other_device');
    final when = DateFormat.yMMMd().add_jm().format(last);
    return translate('backup_detail_last').replaceAll('{when}', when);
  }
}
