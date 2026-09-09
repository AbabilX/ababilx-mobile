import 'package:drift/drift.dart';

import '../models/chat_message.dart';
import 'chat_local_db.dart';
import 'chat_message_row.dart';

/// Existing cross-platform store kept during the Android encrypted migration.
class DriftChatMessageStore {
  DriftChatMessageStore(this._db, {required this.keepPerConversation});

  final ChatLocalDb _db;
  final int keepPerConversation;

  Future<List<ChatMessage>> page(
    String conversationId, {
    required int limit,
    int? beforeMs,
    String? beforeId,
    String? threadRootId,
  }) async {
    if (conversationId.isEmpty) return const [];
    try {
      final query = _db.select(_db.cachedMessages)
        ..where((t) => t.conversationId.equals(conversationId))
        ..where(
          (t) => threadRootId == null
              ? t.threadRootId.isNull()
              : t.threadRootId.equals(threadRootId),
        );
      if (beforeMs != null) {
        query.where(
          (t) => beforeId == null
              ? t.createdAtMs.isSmallerOrEqualValue(beforeMs)
              : t.createdAtMs.isSmallerThanValue(beforeMs) |
                    (t.createdAtMs.equals(beforeMs) &
                        t.id.isSmallerThanValue(beforeId)),
        );
      }
      query
        ..orderBy([
          (t) =>
              OrderingTerm(expression: t.createdAtMs, mode: OrderingMode.desc),
          (t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc),
        ])
        ..limit(limit);
      return messagesFromRows((await query.get()).reversed);
    } catch (_) {
      return const [];
    }
  }

  /// Reads the archive in one ascending keyset cursor, across every
  /// conversation and every thread. See [AndroidChatMessageStore.exportPage]
  /// for why this cannot be [page] with different arguments: `page` filters
  /// `thread_root_id IS NULL`, so it can never see a thread reply.
  Future<List<ChatMessage>> exportPage({
    int? afterMs,
    String? afterId,
    required int limit,
  }) async {
    try {
      final query = _db.select(_db.cachedMessages);
      if (afterMs != null) {
        query.where(
          (t) => afterId == null
              ? t.createdAtMs.isBiggerThanValue(afterMs)
              : t.createdAtMs.isBiggerThanValue(afterMs) |
                    (t.createdAtMs.equals(afterMs) &
                        t.id.isBiggerThanValue(afterId)),
        );
      }
      query
        ..orderBy([
          (t) => OrderingTerm(expression: t.createdAtMs),
          (t) => OrderingTerm(expression: t.id),
        ])
        ..limit(limit);
      return messagesFromRows(await query.get());
    } catch (_) {
      return const [];
    }
  }

  Future<bool> hasOlderThan(
    String conversationId,
    int beforeMs, {
    String? beforeId,
  }) async {
    if (conversationId.isEmpty) return false;
    try {
      final row =
          await (_db.select(_db.cachedMessages)
                ..where((t) => t.conversationId.equals(conversationId))
                ..where((t) => t.threadRootId.isNull())
                ..where(
                  (t) => beforeId == null
                      ? t.createdAtMs.isSmallerThanValue(beforeMs)
                      : t.createdAtMs.isSmallerThanValue(beforeMs) |
                            (t.createdAtMs.equals(beforeMs) &
                                t.id.isSmallerThanValue(beforeId)),
                )
                ..limit(1))
              .getSingleOrNull();
      return row != null;
    } catch (_) {
      return false;
    }
  }

  Future<void> saveAll(List<ChatMessage> messages) async {
    final writable = messages.where((m) => m.id.isNotEmpty).toList();
    if (writable.isEmpty) return;
    try {
      await _db.batch((batch) {
        for (final message in writable) {
          batch.insert(
            _db.cachedMessages,
            messageRow(message),
            mode: InsertMode.insertOrReplace,
          );
        }
      });
      for (final message in writable) {
        if (message.isPending) continue;
        final rowId = localMessageRowId(message);
        await _db.customStatement(
          "DELETE FROM cached_messages WHERE json_extract(payload_json, '\$.id') = ? AND id != ?",
          [message.id, rowId],
        );
      }
      for (final id in writable.map((m) => m.conversationId).toSet()) {
        await _prune(id);
      }
    } catch (_) {}
  }

  Future<void> remove(String messageId) async {
    if (messageId.isEmpty) return;
    await (_db.delete(
      _db.cachedMessages,
    )..where((t) => t.id.equals(messageId))).go();
    await _db.customStatement(
      "DELETE FROM cached_messages WHERE json_extract(payload_json, '\$.id') = ?",
      [messageId],
    );
  }

  Future<List<ChatMessage>> listUnsent() async {
    try {
      final rows =
          await (_db.select(_db.cachedMessages)..where(
                (t) =>
                    t.payloadJson.like('%"send_status":"sending"%') |
                    t.payloadJson.like('%"send_status":"failed"%'),
              ))
              .get();
      return messagesFromRows(rows).where((m) => m.isPending).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<ChatMessage>> search(String query, {required int limit}) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.length < 2) return const [];
    try {
      final rows =
          await (_db.select(_db.cachedMessages)
                ..where((t) => t.searchText.like('%$normalized%'))
                ..orderBy([
                  (t) => OrderingTerm(
                    expression: t.createdAtMs,
                    mode: OrderingMode.desc,
                  ),
                ])
                ..limit(limit))
              .get();
      return messagesFromRows(rows);
    } catch (_) {
      return const [];
    }
  }

  Future<List<ChatMessage>> encryptedPage({
    required int limit,
    required int offset,
  }) async {
    try {
      final rows =
          await (_db.select(_db.cachedMessages)
                ..where((t) => t.searchText.equals(''))
                ..where((t) => t.payloadJson.like('%"encryption_version":1%'))
                ..orderBy([
                  (t) => OrderingTerm(
                    expression: t.createdAtMs,
                    mode: OrderingMode.desc,
                  ),
                ])
                ..limit(limit, offset: offset))
              .get();
      return messagesFromRows(
        rows,
      ).where((m) => m.isEncrypted && !m.isDeleted).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> clearConversation(String conversationId) async {
    if (conversationId.isEmpty) return;
    try {
      await (_db.delete(
        _db.cachedMessages,
      )..where((t) => t.conversationId.equals(conversationId))).go();
    } catch (_) {}
  }

  Future<void> clearAll() async {
    try {
      await _db.delete(_db.cachedMessages).go();
    } catch (_) {}
  }

  /// Trims a conversation to [keepPerConversation] rows.
  ///
  /// A runaway backstop, not a retention policy. The phone is the archive and
  /// deliberately holds far more history than the server, which keeps six
  /// months — see CHAT_RETENTION.md. Only a conversation past a couple of
  /// hundred thousand messages ever reaches this.
  Future<void> _prune(String conversationId) async {
    try {
      await _db.customStatement(
        'DELETE FROM cached_messages WHERE conversation_id = ? '
        'AND created_at_ms < (SELECT created_at_ms FROM cached_messages '
        'WHERE conversation_id = ? ORDER BY created_at_ms DESC '
        'LIMIT 1 OFFSET ?)',
        [conversationId, conversationId, keepPerConversation - 1],
      );
    } catch (_) {}
  }
}
