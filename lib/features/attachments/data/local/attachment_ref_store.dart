import 'package:drift/drift.dart';

import '../../../messages/data/local/chat_local_db.dart';

/// Which messages still point at a downloaded blob.
///
/// This is the refcount that makes URL-keyed storage safe: one file can back
/// an original message and every forward of it, so the bytes are only deleted
/// once the last referencing attachment row is gone.
class AttachmentRefStore {
  AttachmentRefStore(this._db);

  final ChatLocalDb _db;

  /// Records every (attachment → blob) edge in one batch. Called on intake,
  /// so a message seen twice simply rewrites the same rows.
  Future<void> indexAll(List<AttachmentRefEntry> entries) async {
    if (entries.isEmpty) return;
    try {
      await _db.batch((batch) {
        for (final entry in entries) {
          if (entry.attachmentId.isEmpty || entry.urlKey.isEmpty) continue;
          batch.insert(
            _db.attachmentRefs,
            AttachmentRefsCompanion.insert(
              attachmentId: entry.attachmentId,
              urlKey: entry.urlKey,
              messageId: entry.messageId,
              conversationId: Value(entry.conversationId),
            ),
            mode: InsertMode.insertOrReplace,
          );
        }
      });
    } catch (_) {}
  }

  /// Drops a deleted message's edges and reports which blobs that orphaned,
  /// so the caller can delete their files.
  Future<List<String>> removeForMessage(String messageId) async {
    if (messageId.isEmpty) return const [];
    try {
      final rows = await (_db.select(
        _db.attachmentRefs,
      )..where((t) => t.messageId.equals(messageId))).get();
      if (rows.isEmpty) return const [];
      await (_db.delete(
        _db.attachmentRefs,
      )..where((t) => t.messageId.equals(messageId))).go();
      final orphans = <String>[];
      for (final urlKey in rows.map((r) => r.urlKey).toSet()) {
        if (await refCount(urlKey) == 0) orphans.add(urlKey);
      }
      return orphans;
    } catch (_) {
      return const [];
    }
  }

  Future<int> refCount(String urlKey) async {
    if (urlKey.isEmpty) return 0;
    try {
      final rows = await (_db.select(
        _db.attachmentRefs,
      )..where((t) => t.urlKey.equals(urlKey))).get();
      return rows.length;
    } catch (_) {
      return 0;
    }
  }

  /// Blobs nothing points at any more.
  ///
  /// Two ways that happens: the referencing message was deleted, or it was
  /// pruned out of `cached_messages` by the per-conversation retention cap —
  /// which drops rows silently, so the refs must be checked against it rather
  /// than trusted.
  Future<List<String>> orphanUrlKeys() async {
    try {
      await _db.customStatement(
        'DELETE FROM attachment_refs WHERE message_id NOT IN '
        '(SELECT id FROM cached_messages)',
      );
      final rows = await _db
          .customSelect(
            'SELECT url_key FROM attachment_blobs WHERE url_key NOT IN '
            '(SELECT url_key FROM attachment_refs)',
          )
          .get();
      return [for (final row in rows) row.read<String>('url_key')];
    } catch (_) {
      return const [];
    }
  }

  Future<void> clearAll() async {
    try {
      await _db.delete(_db.attachmentRefs).go();
    } catch (_) {}
  }
}

/// One (attachment → blob) edge, built at intake.
class AttachmentRefEntry {
  const AttachmentRefEntry({
    required this.attachmentId,
    required this.urlKey,
    required this.messageId,
    required this.conversationId,
  });

  final String attachmentId;
  final String urlKey;
  final String messageId;
  final String conversationId;
}
