import 'dart:convert';

import 'package:drift/drift.dart';

import 'chat_local_db.dart';

/// V3 → V4 backfill: the old `cached_message_feeds` table kept the last 50
/// messages of a conversation as one JSON array. Explode those rows into
/// [CachedMessages] rows so an upgrading user keeps the history already on
/// their device instead of staring at an empty chat until the next fetch.
///
/// Best-effort by design: a device whose blob cache is missing or corrupt just
/// refetches from the server, so nothing here is allowed to fail the upgrade.
Future<void> backfillMessageRowsFromFeedBlobs(ChatLocalDb db) async {
  try {
    final rows = await db
        .customSelect(
          'SELECT conversation_id, payload_json '
          'FROM cached_message_feeds',
        )
        .get();
    for (final row in rows) {
      final conversationId = row.read<String>('conversation_id');
      final payload = row.read<String>('payload_json');
      await _insertBlob(db, conversationId, payload);
    }
  } catch (_) {
    // No old table, or unreadable — nothing to carry forward.
  }
  try {
    await db.customStatement('DROP TABLE IF EXISTS cached_message_feeds');
  } catch (_) {}
}

Future<void> _insertBlob(
  ChatLocalDb db,
  String conversationId,
  String payloadJson,
) async {
  try {
    final list = jsonDecode(payloadJson) as List<dynamic>;
    await db.batch((batch) {
      for (final entry in list) {
        final json = entry as Map<String, dynamic>;
        final id = json['id'] as String? ?? '';
        if (id.isEmpty) continue;
        final createdAt = json['created_at'] as String? ?? '';
        batch.insert(
          db.cachedMessages,
          CachedMessagesCompanion.insert(
            id: id,
            conversationId: conversationId,
            createdAtMs:
                DateTime.tryParse(createdAt)?.millisecondsSinceEpoch ?? 0,
            threadRootId: Value(json['parent_id'] as String?),
            payloadJson: jsonEncode(json),
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  } catch (_) {
    // One bad conversation blob must not stop the rest of the backfill.
  }
}
