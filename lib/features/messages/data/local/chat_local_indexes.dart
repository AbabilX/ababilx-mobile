import 'package:drift/drift.dart';

/// Indexes every message query leans on, created on a fresh install as well as
/// on upgrade.
///
/// Until V9 the timeline index existed only on devices that had come up
/// through V4, because `createAll()` knows nothing about hand-written indexes:
/// a phone that signed in fresh — exactly the one running a history restore —
/// answered every page read with a full scan of the archive. The two
/// expression indexes serve the per-row `json_extract` lookups that the
/// confirm path and the boot-time outbox scan make; without them each one
/// read and parsed every stored message.
///
/// The expressions must stay byte-for-byte what the queries write, or SQLite
/// cannot match them to the index.
Future<void> ensureChatMessageIndexes(DatabaseConnectionUser db) async {
  const statements = [
    'CREATE INDEX IF NOT EXISTS idx_cached_messages_timeline '
        'ON cached_messages (conversation_id, thread_root_id, created_at_ms, id)',
    // The archive cursor (backup, history transfer): every row by time, then
    // id. Without it each export page sorted the whole table again.
    'CREATE INDEX IF NOT EXISTS idx_cached_messages_archive '
        'ON cached_messages (created_at_ms, id)',
    "CREATE INDEX IF NOT EXISTS idx_cached_messages_payload_id "
        "ON cached_messages (json_extract(payload_json, '\$.id'))",
    "CREATE INDEX IF NOT EXISTS idx_cached_messages_send_status "
        "ON cached_messages (json_extract(payload_json, '\$.send_status'))",
  ];
  for (final statement in statements) {
    await db.customStatement(statement);
  }
}
