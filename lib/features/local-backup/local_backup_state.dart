import 'data/local_backup_settings.dart';

enum LocalBackupPhase { idle, backingUp, restoring }

class LocalBackupState {
  const LocalBackupState({
    this.phase = LocalBackupPhase.idle,
    this.progress = 0,
    this.bytesRead = 0,
    this.bytesTotal = 0,
    this.settings = const LocalBackupSettings(),
    this.loaded = false,
  });

  final LocalBackupPhase phase;

  /// Messages written or restored so far — a count, not a percentage, for
  /// the archive's reason: the total is unknown until the end.
  final int progress;

  /// How far a restore has read through the backup file, for the chat
  /// list's "Restoring · 236 KB of 1.6 MB" (Signal's restore banner).
  final int bytesRead;
  final int bytesTotal;
  final LocalBackupSettings settings;
  final bool loaded;

  bool get busy => phase != LocalBackupPhase.idle;

  LocalBackupState copyWith({
    LocalBackupPhase? phase,
    int? progress,
    int? bytesRead,
    int? bytesTotal,
    LocalBackupSettings? settings,
    bool? loaded,
  }) => LocalBackupState(
    phase: phase ?? this.phase,
    progress: progress ?? this.progress,
    bytesRead: bytesRead ?? this.bytesRead,
    bytesTotal: bytesTotal ?? this.bytesTotal,
    settings: settings ?? this.settings,
    loaded: loaded ?? this.loaded,
  );
}
