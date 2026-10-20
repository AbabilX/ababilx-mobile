/// One triage step the user can Undo.
enum CatchUpStep { markedRead, keptUnread }

/// Pure deck for Catch up: remaining chat ids, and an undo stack of the
/// last steps. No Flutter, no Riverpod — the screen owns side effects
/// (mark-read API) and feeds ids in.
class CatchUpQueue {
  CatchUpQueue(Iterable<String> ids)
    : remaining = [for (final id in ids) id],
      undo = [];

  final List<String> remaining;
  final List<({String id, CatchUpStep step})> undo;

  bool get isEmpty => remaining.isEmpty;
  int get left => remaining.length;
  String? get current => remaining.isEmpty ? null : remaining.first;
  bool get canUndo => undo.isNotEmpty;

  /// The cards stuck behind the front one, nearest first (at most [n]).
  List<String> behind([int n = 2]) {
    if (remaining.length < 2 || n < 1) return const [];
    final end = remaining.length < 1 + n ? remaining.length : 1 + n;
    return remaining.sublist(1, end);
  }

  /// Mark / keep: drop the front card and remember how, for Undo.
  void advance(CatchUpStep step) {
    if (remaining.isEmpty) return;
    final id = remaining.removeAt(0);
    undo.add((id: id, step: step));
  }

  /// Put the last stepped card back on top. Returns the step that was
  /// undone, or null when there is nothing to undo.
  CatchUpStep? revert() {
    if (undo.isEmpty) return null;
    final last = undo.removeLast();
    remaining.insert(0, last.id);
    return last.step;
  }
}
