import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../messages/message_e2ee/message_vault.dart';
import '../../messages/providers/chat_provider.dart';
import '../data/local_backup_settings.dart';
import '../data/restore_choice_store.dart';
import '../platform/backup_folder_channel.dart';
import '../restore/backup_restore_source.dart';
import '../local_backup_provider.dart';
import 'local_backup_restore_flow.dart';
import 'restore_offer_sheet.dart';

/// Invisible host in the home shell for the two things local backup does on
/// its own: the scheduled run, and bringing a backup back after this phone
/// got a new session for the account.
///
/// Scheduled means "when the app opens, at most once in 12 hours" — there is
/// no background job yet, on purpose: a backup reads the unlocked message key,
/// which lives in this process, and a WorkManager isolate would have to
/// rebuild the whole vault to do it. The run waits 20 s after launch or resume
/// so it never competes with the chat list loading.
class LocalBackupWatcher extends ConsumerStatefulWidget {
  const LocalBackupWatcher({super.key});

  @override
  ConsumerState<LocalBackupWatcher> createState() => _LocalBackupWatcherState();
}

class _LocalBackupWatcherState extends ConsumerState<LocalBackupWatcher>
    with WidgetsBindingObserver {
  static const _settle = Duration(seconds: 20);
  static const _retry = Duration(seconds: 5);
  Timer? _timer;
  bool _checking = false;
  int _attempts = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _attempts = 0;
      _check();
    }
  }

  Future<void> _check() async {
    if (_checking || !mounted) return;
    _checking = true;
    try {
      final userId = ref.read(chatProvider).currentUserId;
      // Bootstrap unlocks the vault a moment after the shell appears; keep
      // looking for a short while rather than miss the offer until a resume.
      if (userId.isEmpty || !ref.read(messageVaultProvider).isUnlocked) {
        if (_attempts++ < 12) {
          _timer?.cancel();
          _timer = Timer(_retry, _check);
        }
        return;
      }
      await _restoreIfWaiting(userId);
      if (!mounted) return;
      _timer?.cancel();
      _timer = Timer(_settle, () {
        if (mounted) ref.read(localBackupProvider.notifier).runIfDue();
      });
    } finally {
      _checking = false;
    }
  }

  /// A restore armed by a recovery-code unlock or "start fresh".
  ///
  /// The automatic folder is looked in first. A backup of this account there
  /// comes back without a question after a recovery-code unlock, and after
  /// one question following "start fresh" — the person chose, a moment ago,
  /// to leave history behind. Nothing readable there (no backup, or a
  /// reinstall hid it) is the old offer: Restore opens the folder grant.
  Future<void> _restoreIfWaiting(String userId) async {
    const store = LocalBackupSettingsStore();
    final offer = await store.pendingRestoreOffer(userId);
    if (offer == null || !mounted) return;
    if (!LocalBackupSettingsStore.automatic) {
      return store.clearRestoreOffer(userId);
    }
    final notifier = ref.read(localBackupProvider.notifier);
    if (ref.read(localBackupProvider).busy) return;
    var found = await notifier.findAutomatic();
    // "Continue with local backup" after a reinstall: the backup was found
    // in a folder the person granted, before the new key was made.
    // Read either way: a grant taken while the automatic folder was still
    // being looked at is given back too.
    final granted = await _choice.folder(userId);
    if (found.isEmpty && granted != null) {
      found = await grantedBackupSources(
        const BackupFolderChannel(),
        granted,
        userId,
      ).catchError((_) => const <BackupRestoreSource>[]);
    }
    if (!mounted) return;
    if (found.isEmpty) {
      await store.clearRestoreOffer(userId);
      await _forgetChoice(userId, granted);
      if (!mounted || !await askRestoreFromBackup(context, ref)) return;
      if (mounted) {
        await startLocalBackupRestore(context, ref, grantBackups: true);
      }
      return;
    }
    if (offer == RestoreOffer.ask) {
      await store.clearRestoreOffer(userId);
      if (!mounted) return;
      final go = await askRestoreFromBackup(
        context,
        ref,
        foundAtMs: found.first.createdAtMs,
      );
      if (!go || !mounted) return;
    }
    final error = await runLocalBackupRestore(context, found, openChats: false);
    // Offline or still locked: the offer stays and the next resume tries
    // again. Anything else was a real answer.
    if (_tryAgain.contains(error)) return;
    await store.clearRestoreOffer(userId);
    await _forgetChoice(userId, granted);
  }

  static const _choice = RestoreChoiceStore();

  /// The folder was granted for this one restore; it is given back.
  Future<void> _forgetChoice(String userId, String? granted) async {
    await _choice.clear(userId);
    if (granted == null) return;
    await const BackupFolderChannel().releaseFolder(granted).catchError((_) {});
  }

  static const _tryAgain = {
    'local_backup_error_key',
    'local_backup_error_locked',
    'local_backup_error_busy',
  };

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
