import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat_message.dart';
import 'android_chat_message_store.dart';
import 'chat_local_db.dart';
import 'chat_sidebar_cache.dart' show chatLocalDbProvider;
import 'drift_chat_message_store.dart';

export 'local_message_search.dart';

/// Local retention backstop: the most messages one conversation keeps on the
/// device.
///
/// This is NOT the retention policy and must not be read as one. The phone is
/// the archive and deliberately outlives the server, which keeps six months —
/// see CHAT_RETENTION.md. This exists so a runaway feed cannot fill the disk;
/// at 200k messages a conversation is already far past anything the server
/// still holds.
const int pruneKeepPerConversation = 200000;

/// Upper bound on ONE page read out of the local store. Separate from the
/// retention ceiling on purpose: raising how much the phone KEEPS must never
/// raise how much a single query can pull into memory.
const int localPageCeiling = 2000;
const int diskPageSize = 50;

/// Durable history facade.
///
/// Android reads SQLCipher first. Drift remains a temporary rollback copy and
/// migration source, so an upgrade cannot make existing offline history vanish.
class ChatMessageStore {
  ChatMessageStore(
    ChatLocalDb db, {
    this.keepPerConversation = pruneKeepPerConversation,
    AndroidChatMessageStore? androidStore,
  }) : _drift = DriftChatMessageStore(
         db,
         keepPerConversation: keepPerConversation,
       ),
       _android = androidStore;

  final int keepPerConversation;
  final DriftChatMessageStore _drift;
  final AndroidChatMessageStore? _android;

  Future<List<ChatMessage>> page(
    String conversationId, {
    int limit = diskPageSize,
    int? beforeMs,
    String? beforeId,
    String? threadRootId,
  }) async {
    if (conversationId.isEmpty) return const [];
    final native = _android;
    if (native == null) {
      return _drift.page(
        conversationId,
        limit: limit,
        beforeMs: beforeMs,
        beforeId: beforeId,
        threadRootId: threadRootId,
      );
    }
    try {
      final scope = jsonEncode([conversationId, threadRootId]);
      if (!await native.isLegacyMigrated(scope)) {
        // Migrate the entire retained slice before marking this scope done.
        // Re-running after a crash is harmless because id is the conflict key.
        final legacy = await _drift.page(
          conversationId,
          limit: localPageCeiling,
          threadRootId: threadRootId,
        );
        await native.migrateLegacy(scope, legacy);
      }
      return native.page(
        conversationId,
        limit: limit,
        beforeMs: beforeMs,
        beforeId: beforeId,
        threadRootId: threadRootId,
      );
    } catch (_) {
      return _drift.page(
        conversationId,
        limit: limit,
        beforeMs: beforeMs,
        beforeId: beforeId,
        threadRootId: threadRootId,
      );
    }
  }

  Future<bool> hasOlderThan(
    String conversationId,
    int beforeMs, {
    String? beforeId,
  }) async {
    final native = _android;
    if (native != null) {
      try {
        if (await native.hasOlderThan(
          conversationId,
          beforeMs,
          beforeId: beforeId,
        )) {
          return true;
        }
      } catch (_) {}
    }
    return _drift.hasOlderThan(conversationId, beforeMs, beforeId: beforeId);
  }

  Future<void> saveAll(List<ChatMessage> messages) async {
    final native = _android;
    if (native != null) {
      try {
        await native.upsert(messages);
      } catch (_) {
        // Drift below remains a safe write path if the platform store fails.
      }
    }
    await _drift.saveAll(messages);
  }

  Future<void> saveOne(ChatMessage message) => saveAll([message]);

  Future<List<ChatMessage>> listUnsent() async {
    final native = _android;
    if (native != null) {
      try {
        final rows = await native.listUnsent();
        if (rows.isNotEmpty) return rows;
      } catch (_) {}
    }
    return _drift.listUnsent();
  }

  Future<void> remove(String messageId) async {
    final native = _android;
    if (native != null) {
      try {
        await native.remove(messageId);
      } catch (_) {}
    }
    await _drift.remove(messageId);
  }

  Future<List<ChatMessage>> search(String query, {int limit = 30}) =>
      _drift.search(query, limit: limit);

  Future<List<ChatMessage>> encryptedPage({int limit = 200, int offset = 0}) =>
      _drift.encryptedPage(limit: limit, offset: offset);

  Future<void> clearConversation(String conversationId) async {
    final native = _android;
    if (native != null) {
      try {
        await native.clearConversation(conversationId);
      } catch (_) {}
    }
    await _drift.clearConversation(conversationId);
  }

  Future<void> clearAll() async {
    final native = _android;
    if (native != null) {
      try {
        await native.clearAll();
      } catch (_) {}
    }
    await _drift.clearAll();
  }
}

final chatMessageStoreProvider = Provider<ChatMessageStore>(
  (ref) => ChatMessageStore(
    ref.watch(chatLocalDbProvider),
    androidStore: Platform.isAndroid ? const AndroidChatMessageStore() : null,
  ),
);
