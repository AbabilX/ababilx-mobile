/// How many conversations to pull at once. One is too slow on a long list;
/// more than a few contends with the chat the user just opened.
const historyRestoreConcurrency = 2;

/// Walks [ids] with a small worker pool and reports progress after each one.
///
/// A failed [pull] still counts as done so a dead conversation cannot stall
/// the banner forever. The caller re-checks disk afterwards to decide whether
/// the pending flag should stay set.
Future<void> runHistoryRestore({
  required List<String> ids,
  required Future<void> Function(String id) pull,
  required void Function(int done, int total) onProgress,
  required bool Function() shouldStop,
  String? Function()? prioritized,
  int concurrency = historyRestoreConcurrency,
}) async {
  final total = ids.length;
  if (total == 0) {
    onProgress(0, 0);
    return;
  }
  onProgress(0, total);
  final queue = [...ids];
  var done = 0;

  // The conversation the user is looking at jumps the queue the moment a
  // worker is free, so an open chat is never waiting behind the whole list.
  String? take() {
    if (queue.isEmpty) return null;
    final wanted = prioritized?.call();
    if (wanted != null && queue.remove(wanted)) return wanted;
    return queue.removeAt(0);
  }

  Future<void> worker() async {
    while (!shouldStop()) {
      final id = take();
      if (id == null) return;
      try {
        await pull(id);
      } catch (_) {}
      done += 1;
      onProgress(done, total);
    }
  }

  final workers = concurrency.clamp(1, total);
  await Future.wait(List<Future<void>>.generate(workers, (_) => worker()));
}
