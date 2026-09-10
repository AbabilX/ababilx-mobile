import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/chat_provider.dart';

import 'archive_api.dart';
import 'archive_service.dart';

enum ArchivePhase { idle, backingUp, restoring }

class ArchiveState {
  const ArchiveState({
    this.phase = ArchivePhase.idle,
    this.progress = 0,
    this.error = '',
    this.lastBackupAt,
    this.remote,
    this.loaded = false,
  });

  final ArchivePhase phase;

  /// Frames written or rows restored so far. Deliberately a count and not a
  /// percentage: the total is not known until the export finishes, and a
  /// progress bar that guesses is worse than a number that is true.
  final int progress;
  final String error;
  final DateTime? lastBackupAt;

  /// What the server currently holds, or null when nothing has been committed.
  final ArchiveManifest? remote;
  final bool loaded;

  bool get busy => phase != ArchivePhase.idle;

  ArchiveState copyWith({
    ArchivePhase? phase,
    int? progress,
    String? error,
    DateTime? lastBackupAt,
    ArchiveManifest? remote,
    bool clearRemote = false,
    bool? loaded,
  }) => ArchiveState(
    phase: phase ?? this.phase,
    progress: progress ?? this.progress,
    error: error ?? this.error,
    lastBackupAt: lastBackupAt ?? this.lastBackupAt,
    remote: clearRemote ? null : (remote ?? this.remote),
    loaded: loaded ?? this.loaded,
  );
}

class ArchiveNotifier extends Notifier<ArchiveState> {
  @override
  ArchiveState build() {
    ref.onDispose(() => _cancelled = true);
    return const ArchiveState();
  }

  bool _cancelled = false;
  Future<void>? _recoveryRun;
  Future<void> cancel() async {
    _cancelled = true;
    try {
      await _recoveryRun;
    } catch (_) {}
  }

  Future<void> markRecoveryPending() async {
    final id = await ref.read(chatProvider.notifier).ensureCurrentUserId();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('archive_recovery_pending_$id', true);
  }

  Future<void> restoreAfterRecovery() => _recoveryRun ??=
      _restoreAfterRecovery().whenComplete(() => _recoveryRun = null);
  Future<void> _restoreAfterRecovery() async {
    final id = await ref.read(chatProvider.notifier).ensureCurrentUserId();
    final prefs = await SharedPreferences.getInstance();
    if (_cancelled || prefs.getBool('archive_recovery_pending_$id') != true) {
      return;
    }
    await refresh();
    if (_cancelled || state.error.isNotEmpty) return;
    if (state.remote != null && await restore() == null) return;
    if (!_cancelled) await prefs.remove('archive_recovery_pending_$id');
  }

  ArchiveService get _service => ref.read(archiveServiceProvider);

  Future<void> refresh() async {
    try {
      final remote = await _service.manifest();
      final last = await _service.lastBackupAt();
      if (_cancelled) return;
      state = state.copyWith(
        remote: remote,
        clearRemote: remote == null,
        lastBackupAt: last,
        loaded: true,
        error: '',
      );
    } catch (error) {
      if (!_cancelled) {
        state = state.copyWith(loaded: true, error: _describe(error));
      }
    }
  }

  Future<bool> backUp({required String deviceId, required int nowMs}) async {
    if (state.busy) return false;
    state = state.copyWith(
      phase: ArchivePhase.backingUp,
      progress: 0,
      error: '',
    );
    try {
      await _service.backUp(
        deviceId: deviceId,
        nowMs: nowMs,
        onProgress: (frames) => state = state.copyWith(progress: frames),
      );
      state = state.copyWith(phase: ArchivePhase.idle);
      await refresh();
      return true;
    } catch (error) {
      state = state.copyWith(phase: ArchivePhase.idle, error: _describe(error));
      return false;
    }
  }

  Future<int?> restore() async {
    if (state.busy) return null;
    state = state.copyWith(
      phase: ArchivePhase.restoring,
      progress: 0,
      error: '',
    );
    try {
      final result = await _service.restore(
        shouldContinue: () => !_cancelled,
        onProgress: (restored) {
          if (!_cancelled) state = state.copyWith(progress: restored);
        },
      );
      if (_cancelled) return null;
      state = state.copyWith(phase: ArchivePhase.idle);
      return result.restored;
    } catch (error) {
      if (!_cancelled) {
        state = state.copyWith(
          phase: ArchivePhase.idle,
          error: _describe(error),
        );
      }
      return null;
    }
  }

  /// A locked vault is the one failure with a real remedy, so it says so
  /// rather than collapsing into "something went wrong".
  String _describe(Object error) {
    if (error is ArchiveLockedError) {
      return 'Unlock secure messages first, then try again.';
    }
    return 'Could not reach the backup. Check your connection.';
  }
}

final archiveProvider = NotifierProvider<ArchiveNotifier, ArchiveState>(
  ArchiveNotifier.new,
);
