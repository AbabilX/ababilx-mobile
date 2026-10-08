import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/local_backup_failure.dart';
import 'local_backup_restore_runner.dart';
import 'local_backup_runner.dart';
import 'local_backup_state.dart';
import 'restore/backup_importer.dart';
import 'restore/backup_restore_source.dart';

/// The restoring half of `LocalBackupNotifier`, kept apart for size.
mixin LocalBackupRestoring on Notifier<LocalBackupState> {
  /// Set by `cancel()`; every long loop asks it between steps.
  bool cancelled = false;

  Future<String> currentUser();

  /// The backups this install can read in the automatic folder, newest
  /// first. Empty when there is none — and after a reinstall, when Android
  /// hides the old files until the folder is granted again.
  Future<List<BackupRestoreSource>> findAutomatic() async {
    try {
      final (dir, _) = await LocalBackupRunner(
        ref,
      ).accountDir(await currentUser());
      return await accountDirSources(dir);
    } catch (error) {
      debugPrint('[LocalBackup] automatic folder not read: $error');
      return const [];
    }
  }

  /// Restores the first of [sources] that is a whole backup. An incomplete
  /// or damaged newest file falls through to the one before it — that is
  /// what the second copy is kept for.
  Future<(BackupRestoreStats?, String?)> restoreFirst(
    List<BackupRestoreSource> sources,
  ) async {
    (BackupRestoreStats?, String?) last = (null, 'local_backup_error_generic');
    for (final source in sources) {
      last = await restore(source);
      final error = last.$2;
      if (error != 'local_backup_error_incomplete' &&
          error != 'local_backup_error_damaged') {
        break;
      }
    }
    return last;
  }

  Future<(BackupRestoreStats?, String?)> restore(
    BackupRestoreSource source,
  ) async {
    if (state.busy) return (null, LocalBackupFailure.busy.messageKey);
    cancelled = false;
    state = state.copyWith(
      phase: LocalBackupPhase.restoring,
      progress: 0,
      bytesRead: 0,
      bytesTotal: source.bytes,
    );
    try {
      final stats = await LocalBackupRestoreRunner(ref).restore(
        userId: await currentUser(),
        source: source,
        onProgress: (n) {
          if (!cancelled) state = state.copyWith(progress: n);
        },
        onBytes: (read, total) {
          if (!cancelled) {
            state = state.copyWith(bytesRead: read, bytesTotal: total);
          }
        },
        shouldContinue: () => !cancelled,
      );
      return (stats, null);
    } catch (error) {
      debugPrint('[LocalBackup] restore failed: $error');
      return (null, localBackupFailureKey(error));
    } finally {
      state = state.copyWith(phase: LocalBackupPhase.idle);
    }
  }
}
