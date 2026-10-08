import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/onboarding/onboarding_option_card.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../messages/providers/chat_provider.dart';
import '../data/local_backup_settings.dart';
import '../data/restore_choice_store.dart';
import '../local_backup_provider.dart';
import '../platform/backup_folder_channel.dart';
import '../restore/backup_restore_source.dart';
import 'restore_account_backup_sheet.dart';

/// The "Continue with local backup" card for the restore-account screen, or
/// null where no local backup exists (anything but Android).
Widget? localBackupAccountOption({
  required bool busy,
  required VoidCallback onStartFresh,
}) => LocalBackupSettingsStore.automatic
    ? LocalBackupAccountCard(enabled: !busy, onStartFresh: onStartFresh)
    : null;

/// A third way into the account, for someone without the recovery code:
/// a new message key (the same step as "Continue without restoring"), then
/// the chats come back from the backup this phone made.
///
/// The backup is found BEFORE anything is reset. After a reinstall Android
/// hides the old files, so the card first asks for the folder; a folder with
/// no backup of this account changes nothing.
class LocalBackupAccountCard extends ConsumerStatefulWidget {
  const LocalBackupAccountCard({
    super.key,
    required this.enabled,
    required this.onStartFresh,
  });

  final bool enabled;
  final VoidCallback onStartFresh;

  @override
  ConsumerState<LocalBackupAccountCard> createState() => _State();
}

class _State extends ConsumerState<LocalBackupAccountCard> {
  static const _store = RestoreChoiceStore();
  static const _folder = BackupFolderChannel();
  List<BackupRestoreSource> _found = const [];
  bool _busy = false;
  late final Future<void> _looked;

  @override
  void initState() {
    super.initState();
    _looked = _look();
  }

  Future<String> _user() =>
      ref.read(chatProvider.notifier).ensureCurrentUserId();

  Future<void> _look() async {
    try {
      final userId = await _user();
      // This screen is where the choice is made: one left by a try that
      // never finished must not answer for the plain "continue without".
      final stale = await _store.folder(userId);
      await _store.clear(userId);
      if (stale != null) await _folder.releaseFolder(stale).catchError((_) {});
      if (!mounted) return;
      final found = await ref
          .read(localBackupProvider.notifier)
          .findAutomatic();
      if (mounted) setState(() => _found = found);
    } catch (_) {}
  }

  Future<void> _tap() async {
    if (_busy) return;
    setState(() => _busy = true);
    String tr(String key) => AppTranslations.translate(context, ref, key);
    String? granted;
    try {
      // A tap that beat the first look must not ask for a folder this
      // install can already read.
      await _looked.timeout(const Duration(seconds: 3), onTimeout: () {});
      final userId = await _user();
      var sources = _found;
      if (sources.isEmpty) {
        final picked = await _folder.pickFolder(atBackups: true);
        if (picked == null) return;
        granted = picked.uri;
        sources = await grantedBackupSources(_folder, picked.uri, userId);
        if (!mounted) return;
        if (sources.isEmpty) {
          showAppToast(context, tr('restore_backup_none'), isError: true);
          return;
        }
      }
      if (!mounted) return;
      if (!await confirmContinueWithBackup(context, ref, sources.first)) return;
      await _store.choose(userId, folderUri: granted);
      // Kept from here on: the restore after the new key reads it.
      granted = null;
      widget.onStartFresh();
    } catch (_) {
      if (mounted) {
        showAppToast(
          context,
          tr('local_backup_error_folder_io'),
          isError: true,
        );
      }
    } finally {
      if (granted != null) {
        await _folder.releaseFolder(granted).catchError((_) {});
      }
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String tr(String key) => AppTranslations.translate(context, ref, key);
    return OnboardingOptionCard(
      icon: HugeIcons.strokeRoundedDatabaseRestore,
      title: tr('restore_select_backup_title'),
      subtitle: _found.isEmpty
          ? tr('restore_select_backup_find')
          : accountBackupLabel(_found.first, tr),
      enabled: widget.enabled && !_busy,
      onTap: _tap,
    );
  }
}
