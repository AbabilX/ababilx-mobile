import 'history_transfer_exporter.dart';

/// What the phone is doing for a transfer it approved.
///
/// Sending is deliberately NOT modal: the user approved a transfer, they did
/// not agree to stare at a progress bar for an hour of video. The state lives
/// here so a sheet can show it and the chat list can carry a quiet line.
class HistoryTransferState {
  const HistoryTransferState({
    this.transferId = '',
    this.phase,
    this.done = 0,
    this.total = 0,
    this.missingFiles = 0,
    this.error = '',
    this.finished = false,
    this.batch = 0,
    this.batches = 0,
    this.waiting = false,
  });

  final String transferId;
  final HistoryTransferPhase? phase;
  final int done;
  final int total;

  /// Files the phone no longer holds. Reported apart from progress, because a
  /// transfer that moved every message and four missing photos must never
  /// read as "everything transferred".
  final int missingFiles;
  final String error;
  final bool finished;

  /// v2 only: which batch is moving, of how many, and whether the phone is
  /// waiting for the browser to save the last one before sending the next.
  final int batch;
  final int batches;
  final bool waiting;

  bool get busy => transferId.isNotEmpty && !finished && error.isEmpty;

  HistoryTransferState copyWith({
    String? transferId,
    HistoryTransferPhase? phase,
    int? done,
    int? total,
    int? missingFiles,
    String? error,
    bool? finished,
    int? batch,
    int? batches,
    bool? waiting,
  }) => HistoryTransferState(
    transferId: transferId ?? this.transferId,
    phase: phase ?? this.phase,
    done: done ?? this.done,
    total: total ?? this.total,
    missingFiles: missingFiles ?? this.missingFiles,
    error: error ?? this.error,
    finished: finished ?? this.finished,
    batch: batch ?? this.batch,
    batches: batches ?? this.batches,
    waiting: waiting ?? this.waiting,
  );
}
