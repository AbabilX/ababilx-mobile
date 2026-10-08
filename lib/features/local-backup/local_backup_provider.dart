import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../messages/providers/chat_provider.dart';
import 'data/backup_choices.dart';
import 'data/local_backup_failure.dart';
import 'data/local_backup_settings.dart';
import 'local_backup_provider_restore.dart';
import 'local_backup_runner.dart';
import 'local_backup_state.dart';
import 'platform/backup_folder_channel.dart';

export 'local_backup_state.dart';

/// Settings → Backup → Local backup, and the scheduled run behind it.
///
/// Every setting is this account's on this phone (see [LocalBackupSettings]).
/// One run at a time, backup or restore; a second asks answer "busy".
class LocalBackupNotifier extends Notifier<LocalBackupState>
    with LocalBackupRestoring {
  static const _store = LocalBackupSettingsStore();
  static const _folder = BackupFolderChannel();

  /// Twice a day, checked when the app opens or comes back. The two newest
  /// are kept.
  static const backupInterval = Duration(hours: 12);

  String _userId = '';

  @override
  LocalBackupState build() {
    ref.onDispose(() => cancelled = true);
    Future.microtask(load);
    return const LocalBackupState();
  }

  LocalBackupRunner get _runner => LocalBackupRunner(ref);

  Future<String> _user() async =>
      _userId = await ref.read(chatProvider.notifier).ensureCurrentUserId();

  @override
  Future<String> currentUser() => _user();

  /// Leaves [LocalBackupState.loaded] false when the account cannot be
  /// named yet (signed out, offline first run): nothing is shown or run.
  Future<void> load() async {
    try {
      final settings = await _store.read(await _user());
      state = state.copyWith(settings: settings, loaded: true);
    } catch (error) {
      debugPrint('[LocalBackup] settings not loaded: $error');
    }
  }

  Future<void> _save(LocalBackupSettings settings) async {
    state = state.copyWith(settings: settings);
    await _store.write(_userId.isEmpty ? await _user() : _userId, settings);
  }

  /// On needs nothing from the person: with no folder picked the backup goes
  /// to the automatic folder. The first backup follows on the next scheduled
  /// check, or at once from "Back up now".
  Future<void> setEnabled(bool enabled) =>
      _save(state.settings.copyWith(enabled: enabled, clearFailure: true));

  /// Returns the failure key, or null when the folder changed (or the picker
  /// was closed).
  Future<String?> changeFolder() async {
    final picked = await _folder.pickFolder();
    if (picked == null) return null;
    if (!picked.writable) return _refuse(picked);
    final old = state.settings.folderUri;
    if (old != null && old != picked.uri) await _folder.releaseFolder(old);
    await _save(
      state.settings.copyWith(
        folderUri: picked.uri,
        folderLabel: picked.label,
        clearFailure: true,
      ),
    );
    return null;
  }

  /// A folder Android will not put our file in: give its grant back and say
  /// why, before anything is switched on.
  Future<String> _refuse(PickedFolder picked) async {
    await _folder.releaseFolder(picked.uri).catchError((_) {});
    return LocalBackupFailure.folderRefused.messageKey;
  }

  /// Back to the automatic folder. Files in the picked folder stay there.
  Future<void> useAutomaticFolder() async {
    final old = state.settings.folderUri;
    if (old != null) await _folder.releaseFolder(old).catchError((_) {});
    await _save(state.settings.copyWith(clearFolder: true, clearFailure: true));
  }

  /// Off. A picked folder keeps its files — the person put them there. The
  /// automatic folder is the app's doing, so [deleteAutomatic] removes this
  /// account's backup from it: off must be able to mean "no copy on this
  /// phone".
  Future<void> disable({bool deleteAutomatic = false}) async {
    final uri = state.settings.folderUri;
    if (uri != null) await _folder.releaseFolder(uri).catchError((_) {});
    if (deleteAutomatic) {
      try {
        final (dir, _) = await _runner.accountDir(await _user());
        await dir.deleteAll();
      } catch (_) {}
    }
    await _save(LocalBackupSettings(choices: state.settings.choices));
  }

  Future<void> setChoices(BackupChoices choices) =>
      _save(state.settings.copyWith(choices: choices));

  /// Returns the failure's translation key, or null on success.
  Future<String?> backUpNow() async {
    if (state.busy) return LocalBackupFailure.busy.messageKey;
    cancelled = false;
    state = state.copyWith(phase: LocalBackupPhase.backingUp, progress: 0);
    try {
      final (entry, _) = await _runner.backUp(
        userId: await _user(),
        settings: state.settings,
        onProgress: (n) {
          if (!cancelled) state = state.copyWith(progress: n);
        },
        shouldContinue: () => !cancelled,
      );
      await _save(
        state.settings.copyWith(
          lastBackupMs: DateTime.now().millisecondsSinceEpoch,
          lastBackupBytes: entry.bytes,
          clearFailure: true,
        ),
      );
      return null;
    } catch (error) {
      debugPrint('[LocalBackup] backup failed: $error');
      final key = localBackupFailureKey(error);
      await _save(state.settings.copyWith(lastFailureKey: key));
      return key;
    } finally {
      state = state.copyWith(phase: LocalBackupPhase.idle);
    }
  }

  /// The scheduled run (every [backupInterval]). Silent: a failure is recorded for the screen, never
  /// raised over whatever the person is doing.
  Future<void> runIfDue() async {
    // Re-read every time: the account may have changed since the last run,
    // and settings are per account.
    await load();
    final s = state.settings;
    if (!LocalBackupSettingsStore.automatic || !s.enabled || state.busy) {
      return;
    }
    // A restore still waiting comes first: this phone may hold almost
    // nothing yet, and its backup would push out the one to restore from.
    if (await _store.pendingRestoreOffer(_userId) != null) return;
    final last = s.lastBackupMs;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (last != null && now - last < backupInterval.inMilliseconds) return;
    await backUpNow();
  }

  void cancel() => cancelled = true;
}

final localBackupProvider =
    NotifierProvider<LocalBackupNotifier, LocalBackupState>(
      LocalBackupNotifier.new,
    );
