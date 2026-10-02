import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../messages/providers/chat_provider.dart';
import 'data/backup_choices.dart';
import 'data/local_backup_failure.dart';
import 'data/local_backup_settings.dart';
import 'local_backup_runner.dart';
import 'local_backup_state.dart';
import 'platform/backup_folder_channel.dart';
import 'restore/backup_importer.dart';

export 'local_backup_state.dart';

/// Settings → Backup → Local backup, and the scheduled run behind it.
///
/// Every setting is this account's on this phone (see [LocalBackupSettings]).
/// One run at a time, backup or restore; a second asks answer "busy".
class LocalBackupNotifier extends Notifier<LocalBackupState> {
  static const _store = LocalBackupSettingsStore();
  static const _folder = BackupFolderChannel();

  /// Twice a day, checked when the app opens or comes back. Each run is a
  /// full copy, so no file depends on an earlier one; the two newest are kept.
  static const backupInterval = Duration(hours: 12);

  bool _cancelled = false;
  String _userId = '';

  @override
  LocalBackupState build() {
    ref.onDispose(() => _cancelled = true);
    Future.microtask(load);
    return const LocalBackupState();
  }

  LocalBackupRunner get _runner => LocalBackupRunner(ref);

  Future<String> _user() async =>
      _userId = await ref.read(chatProvider.notifier).ensureCurrentUserId();

  Future<void> load() async {
    final settings = await _store.read(await _user());
    state = state.copyWith(settings: settings, loaded: true);
  }

  Future<void> _save(LocalBackupSettings settings) async {
    state = state.copyWith(settings: settings);
    await _store.write(_userId.isEmpty ? await _user() : _userId, settings);
  }

  /// Folder picker, then on, then the first backup straight away — a switch
  /// that says "on" with nothing in the folder would be a promise not kept.
  /// Returns the failure key, or null when the backup was written.
  Future<String?> enable() async {
    final picked = await _folder.pickFolder();
    if (picked == null) return 'local_backup_error_cancelled';
    if (!picked.writable) return _refuse(picked);
    await _save(
      state.settings.copyWith(
        enabled: true,
        folderUri: picked.uri,
        folderLabel: picked.label,
        clearFailure: true,
      ),
    );
    return backUpNow();
  }

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

  /// Off, and the folder grant given back. Files already written stay where
  /// they are — they are the person's, and deleting a backup on a switch
  /// would be a surprise nobody could undo.
  Future<void> disable() async {
    final uri = state.settings.folderUri;
    if (uri != null) await _folder.releaseFolder(uri).catchError((_) {});
    await _save(LocalBackupSettings(choices: state.settings.choices));
  }

  Future<void> setChoices(BackupChoices choices) =>
      _save(state.settings.copyWith(choices: choices));

  /// Returns the failure's translation key, or null on success.
  Future<String?> backUpNow() async {
    if (state.busy) return LocalBackupFailure.busy.messageKey;
    _cancelled = false;
    state = state.copyWith(phase: LocalBackupPhase.backingUp, progress: 0);
    try {
      final (entry, _) = await _runner.backUp(
        userId: await _user(),
        settings: state.settings,
        onProgress: (n) {
          if (!_cancelled) state = state.copyWith(progress: n);
        },
        shouldContinue: () => !_cancelled,
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
    if (!s.enabled || !s.hasFolder || state.busy) return;
    final last = s.lastBackupMs;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (last != null && now - last < backupInterval.inMilliseconds) return;
    await backUpNow();
  }

  Future<(BackupRestoreStats?, String?)> restore(String documentUri) async {
    if (state.busy) return (null, LocalBackupFailure.busy.messageKey);
    _cancelled = false;
    state = state.copyWith(
      phase: LocalBackupPhase.restoring,
      progress: 0,
      bytesRead: 0,
      bytesTotal: 0,
    );
    try {
      final stats = await _runner.restore(
        userId: await _user(),
        documentUri: documentUri,
        onProgress: (n) {
          if (!_cancelled) state = state.copyWith(progress: n);
        },
        onBytes: (read, total) {
          if (!_cancelled) {
            state = state.copyWith(bytesRead: read, bytesTotal: total);
          }
        },
        shouldContinue: () => !_cancelled,
      );
      return (stats, null);
    } catch (error) {
      debugPrint('[LocalBackup] restore failed: $error');
      return (null, localBackupFailureKey(error));
    } finally {
      state = state.copyWith(phase: LocalBackupPhase.idle);
    }
  }

  void cancel() => _cancelled = true;
}

final localBackupProvider =
    NotifierProvider<LocalBackupNotifier, LocalBackupState>(
      LocalBackupNotifier.new,
    );
