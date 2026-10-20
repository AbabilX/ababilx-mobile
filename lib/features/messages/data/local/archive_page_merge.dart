import '../models/chat_message.dart';
import 'chat_message_row.dart';

/// Where one stored row sits in the archive cursor: (created_at_ms, row id).
typedef ArchiveRowKey = ({int ms, String id});

/// One page of the Android archive read from BOTH stores, merged.
///
/// SQLCipher answers most of it. Drift still holds rows SQLCipher never got:
/// history from before the encrypted store, in a chat or thread not opened
/// since (a scope migrates only when it is opened), and any row whose native
/// write failed. Read from SQLCipher alone, a backup silently left those out.
///
/// Rows are matched by row id, the cursor's own key, so a message both stores
/// hold appears once and the SQLCipher copy wins. The page is the first
/// [limit] keys of the union — every one of them is inside the first [limit]
/// of its own store, so no row can be skipped between two pages.
Future<List<ChatMessage>> mergeArchivePage({
  required List<ChatMessage> primary,
  required List<ArchiveRowKey> mirrorKeys,
  required Future<List<ChatMessage>> Function(List<String> rowIds) mirrorRows,
  required int limit,
}) async {
  final held = <String, ChatMessage>{
    for (final m in primary) localMessageRowId(m): m,
  };
  final keys = <ArchiveRowKey>[
    for (final m in primary) (ms: messageTimeMs(m), id: localMessageRowId(m)),
    for (final k in mirrorKeys)
      if (!held.containsKey(k.id)) k,
  ]..sort(compareArchiveKeys);
  final page = keys.length > limit ? keys.sublist(0, limit) : keys;
  final missing = [
    for (final k in page)
      if (!held.containsKey(k.id)) k.id,
  ];
  if (missing.isEmpty) return [for (final k in page) held[k.id]!];
  final fetched = {
    for (final m in await mirrorRows(missing)) localMessageRowId(m): m,
  };
  return [for (final k in page) ?(held[k.id] ?? fetched[k.id])];
}

/// Store order: time, then row id. Row ids are ASCII (UUIDs, client refs),
/// where Dart's code-unit order and SQLite's byte order agree.
int compareArchiveKeys(ArchiveRowKey a, ArchiveRowKey b) {
  final byTime = a.ms.compareTo(b.ms);
  return byTime != 0 ? byTime : a.id.compareTo(b.id);
}
