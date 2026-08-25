import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat_message.dart';
import 'chat_local_db.dart';
import 'chat_message_row.dart';
import 'chat_sidebar_cache.dart' show chatLocalDbProvider;

export 'local_message_search.dart';

/// Per-conversation disk history cap.
const int pruneKeepPerConversation = 2000;

/// Default page size for a disk read — matches the server page size, so an
/// offline scroll-back feels the same as an online one.
const int diskPageSize = 50;

/// The durable local chat history: one row per message, paged and searched
/// with indexed queries. Only server-confirmed messages land here — a pending
/// or failed send lives in [PendingOutboxMessages] instead.
class ChatMessageStore {
  ChatMessageStore(
    this._db, {
    this.keepPerConversation = pruneKeepPerConversation,
  });

  final ChatLocalDb _db;

  /// Per-conversation retention. Overridable so a test can exercise pruning
  /// without writing [pruneKeepPerConversation] rows.
  final int keepPerConversation;

  /// One page of [conversationId], oldest → newest (the order the timeline
  /// renders). Pass [beforeMs] to page backwards from a known point; the
  /// bound is inclusive, so a caller must drop ids it already holds — that is
  /// cheaper than losing a message that shares a millisecond with the edge.
  Future<List<ChatMessage>> page(
    String conversationId, {
    int limit = diskPageSize,
    int? beforeMs,
  }) async {
    if (conversationId.isEmpty) return const [];
    try {
      final q = _db.select(_db.cachedMessages)
        ..where((t) => t.conversationId.equals(conversationId));
      if (beforeMs != null) {
        q.where((t) => t.createdAtMs.isSmallerOrEqualValue(beforeMs));
      }
      q
        ..orderBy([
          (t) =>
              OrderingTerm(expression: t.createdAtMs, mode: OrderingMode.desc),
        ])
        ..limit(limit);
      final rows = await q.get();
      return messagesFromRows(rows.reversed);
    } catch (_) {
      return const [];
    }
  }

  /// True when older history than [beforeMs] is on disk — what tells the
  /// timeline whether an offline "load more" has anything left to give.
  Future<bool> hasOlderThan(String conversationId, int beforeMs) async {
    if (conversationId.isEmpty) return false;
    try {
      final row =
          await (_db.select(_db.cachedMessages)
                ..where((t) => t.conversationId.equals(conversationId))
                ..where((t) => t.createdAtMs.isSmallerThanValue(beforeMs))
                ..limit(1))
              .getSingleOrNull();
      return row != null;
    } catch (_) {
      return false;
    }
  }

  /// Upserts every confirmed message in [messages], then prunes the
  /// conversation back to [pruneKeepPerConversation].
  Future<void> saveAll(List<ChatMessage> messages) async {
    final confirmed = messages
        .where((m) => m.sendStatus == MessageSendStatus.sent && m.id.isNotEmpty)
        .toList();
    if (confirmed.isEmpty) return;
    try {
      await _db.batch((batch) {
        for (final m in confirmed) {
          batch.insert(
            _db.cachedMessages,
            messageRow(m),
            mode: InsertMode.insertOrReplace,
          );
        }
      });
      for (final conversationId
          in confirmed.map((m) => m.conversationId).toSet()) {
        await _prune(conversationId);
      }
    } catch (_) {
      // A cache write failure never breaks the live conversation.
    }
  }

  Future<void> saveOne(ChatMessage message) => saveAll([message]);

  Future<void> remove(String messageId) async {
    if (messageId.isEmpty) return;
    try {
      await (_db.delete(
        _db.cachedMessages,
      )..where((t) => t.id.equals(messageId))).go();
    } catch (_) {}
  }

  /// Offline message search, newest first. E2EE DMs never match: their
  /// plaintext is not on disk, so only channels, groups and unencrypted
  /// messages are searchable without a server.
  Future<List<ChatMessage>> search(String query, {int limit = 30}) async {
    final q = query.trim().toLowerCase();
    if (q.length < 2) return const [];
    try {
      final rows =
          await (_db.select(_db.cachedMessages)
                ..where((t) => t.searchText.like('%$q%'))
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

  /// Encrypted rows for vault-backed search; plaintext never reaches SQLite.
  Future<List<ChatMessage>> encryptedPage({
    int limit = 200,
    int offset = 0,
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

  /// Drops everything older than the newest [keepPerConversation] rows. One
  /// indexed statement — no count query first, since below the cap the
  /// sub-select returns nothing and the delete matches nothing. The offset is
  /// `keep - 1` so the row it finds is the oldest one worth keeping.
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

final chatMessageStoreProvider = Provider<ChatMessageStore>(
  (ref) => ChatMessageStore(ref.watch(chatLocalDbProvider)),
);
