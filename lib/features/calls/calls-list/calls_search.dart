import '../../../shared/text/name_search.dart';
import '../data/models/call_log_entry.dart';

/// The Talks tab's search: calls whose person or group name matches [query].
///
/// Client-side over the history already loaded — the server has no call-log
/// search, and the tab pages further while a search is open (see
/// [callSearchPageCap]). Matching goes through [matchesNameQuery], so a
/// decorated name (`𝕄𝕦𝕣𝕒𝕕`, `⋆ Murad ⋆`) is found by its plain letters, as in
/// every other people list. An empty query keeps everything.
List<CallLogEntry> searchCallLog(List<CallLogEntry> calls, String query) {
  if (query.trim().isEmpty) return calls;
  return calls.where((c) => matchesNameQuery(query, [c.title])).toList();
}

/// Extra pages the tab may fetch for one search. A search should reach calls
/// older than the first page, but a failing or endless cursor must not turn
/// one keystroke into a request loop.
const callSearchPageCap = 10;
