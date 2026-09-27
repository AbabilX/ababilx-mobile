import 'package:flutter_riverpod/flutter_riverpod.dart';

enum HistoryRestorePhase { idle, running }

class HistoryRestoreState {
  const HistoryRestoreState({
    this.phase = HistoryRestorePhase.idle,
    this.done = 0,
    this.total = 0,
    this.failed = false,
    this.messages = 0,
    this.messageTotal,
  });

  final HistoryRestorePhase phase;

  /// Conversations walked, of [total].
  final int done;
  final int total;
  final bool failed;

  /// Messages saved so far, and how many the server said there are (null
  /// until it answers, or when it cannot).
  final int messages;
  final int? messageTotal;

  bool get running => phase == HistoryRestorePhase.running;

  HistoryRestoreState copyWith({
    HistoryRestorePhase? phase,
    int? done,
    int? total,
    int? messages,
    int? messageTotal,
  }) => HistoryRestoreState(
    phase: phase ?? this.phase,
    done: done ?? this.done,
    total: total ?? this.total,
    failed: failed,
    messages: messages ?? this.messages,
    messageTotal: messageTotal ?? this.messageTotal,
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

  void setMessageTotal(int total) {
    if (!state.running) return;
    state = state.copyWith(messageTotal: total);
  }

  void addMessages(int count) {
    if (!state.running || count <= 0) return;
    state = state.copyWith(messages: state.messages + count);
  }

  void finish({bool failed = false}) {
    state = HistoryRestoreState(failed: failed);
  }
}

final historyRestoreProvider =
    NotifierProvider<HistoryRestoreNotifier, HistoryRestoreState>(
      HistoryRestoreNotifier.new,
    );
