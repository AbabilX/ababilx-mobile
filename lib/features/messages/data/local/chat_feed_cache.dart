import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat_message.dart';
import 'chat_local_db.dart';
import 'chat_sidebar_cache.dart';

/// Max number of messages stored per conversation in local SQLite cache.
const _maxCachedMessages = 50;

/// Cache-first message feed store. Reads immediately (no network), writes
/// after every successful server load. Pending / failed messages are NEVER
/// written here — only server-confirmed messages land in the cache.
class ChatFeedCache {
  ChatFeedCache(this._db);

  final ChatLocalDb _db;

  /// Returns the last [_maxCachedMessages] messages for [conversationId],
  /// or null if no cache row exists yet.
  Future<List<ChatMessage>?> read(String conversationId) async {
    if (conversationId.isEmpty) return null;
    try {
      final row = await (_db.select(_db.cachedMessageFeeds)
            ..where((t) => t.conversationId.equals(conversationId)))
          .getSingleOrNull();
      if (row == null) return null;
      final list = jsonDecode(row.payloadJson) as List<dynamic>;
      return list
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // Corrupt cache row — treat as cache miss; it will be overwritten.
      return null;
    }
  }

  /// Persists [messages] to the cache, keeping only the most recent
  /// [_maxCachedMessages] confirmed messages (pending/failed excluded).
  Future<void> write(String conversationId, List<ChatMessage> messages) async {
    if (conversationId.isEmpty) return;
    try {
      final confirmed = messages
          .where((m) => m.sendStatus == MessageSendStatus.sent)
          .toList();
      // List is ordered oldest→newest; keep last N.
      final toCache = confirmed.length > _maxCachedMessages
          ? confirmed.sublist(confirmed.length - _maxCachedMessages)
          : confirmed;
      final payload = jsonEncode(toCache.map((m) => m.toJson()).toList());
      await _db.into(_db.cachedMessageFeeds).insertOnConflictUpdate(
            CachedMessageFeedsCompanion.insert(
              conversationId: conversationId,
              payloadJson: payload,
              updatedAtMs: DateTime.now().millisecondsSinceEpoch,
            ),
          );
    } catch (_) {
      // Cache write failure is non-fatal.
    }
  }

  Future<void> clearAll() async {
    try {
      await _db.delete(_db.cachedMessageFeeds).go();
    } catch (_) {}
  }

  Future<void> clearConversation(String conversationId) async {
    if (conversationId.isEmpty) return;
    try {
      await (_db.delete(_db.cachedMessageFeeds)
            ..where((t) => t.conversationId.equals(conversationId)))
          .go();
    } catch (_) {}
  }
}

final chatFeedCacheProvider = Provider<ChatFeedCache>((ref) {
  return ChatFeedCache(ref.watch(chatLocalDbProvider));
});
