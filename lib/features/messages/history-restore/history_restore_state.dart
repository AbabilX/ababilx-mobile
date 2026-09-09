import 'package:flutter_riverpod/flutter_riverpod.dart';

enum HistoryRestorePhase { idle, running }

class HistoryRestoreState {
  const HistoryRestoreState({
    this.phase = HistoryRestorePhase.idle,
    this.done = 0,
    this.total = 0,
  });

  final HistoryRestorePhase phase;
  final int done;
  final int total;

  bool get running => phase == HistoryRestorePhase.running;

  HistoryRestoreState copyWith({
    HistoryRestorePhase? phase,
    int? done,
    int? total,
  }) => HistoryRestoreState(
    phase: phase ?? this.phase,
    done: done ?? this.done,
    total: total ?? this.total,
  );
}

class HistoryRestoreNotifier extends Notifier<HistoryRestoreState> {
  @override
  HistoryRestoreState build() => const HistoryRestoreState();

  void begin(int total) {
    state = HistoryRestoreState(
      phase: HistoryRestorePhase.running,
      done: 0,
      total: total,
    );
  }

  void progress(int done, int total) {
    if (!state.running) return;
    state = state.copyWith(done: done, total: total);
  }

  void finish() {
    state = const HistoryRestoreState();
  }
}

final historyRestoreProvider =
    NotifierProvider<HistoryRestoreNotifier, HistoryRestoreState>(
      HistoryRestoreNotifier.new,
    );
