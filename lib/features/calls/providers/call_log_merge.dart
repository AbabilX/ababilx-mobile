import '../data/models/call_log_entry.dart';

/// A fresh first page laid over the list already on screen.
///
/// The page is the truth for everything it covers — a call deleted on the
/// server inside that window disappears — and the older pages the user
/// scrolled into stay below it, with their cursor. That holds only when the
/// page reaches back into the old list; with no overlap (more new calls than
/// one page) the two cannot be joined, so the page replaces the list.
({List<CallLogEntry> calls, String cursor}) mergeFirstPage({
  required List<CallLogEntry> current,
  required String currentCursor,
  required CallLogPage page,
}) {
  final replace = (calls: page.calls, cursor: page.nextCursor);
  if (page.calls.isEmpty || current.isEmpty) return replace;
  final joinAt = current.indexWhere((c) => c.id == page.calls.last.id);
  if (joinAt < 0) return replace;
  final tail = current.sublist(joinAt + 1);
  if (tail.isEmpty) return replace;
  final onPage = {for (final c in page.calls) c.id};
  return (
    calls: [...page.calls, ...tail.where((c) => !onPage.contains(c.id))],
    cursor: currentCursor,
  );
}
