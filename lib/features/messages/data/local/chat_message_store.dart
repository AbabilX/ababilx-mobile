import 'dart:convert';
import 'dart:io';
import 'chat_deletion_filter.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat_message.dart';
import 'android_chat_message_store.dart';
import 'archive_page_merge.dart';
import 'chat_local_db.dart';
import 'chat_sidebar_cache.dart' show chatLocalDbProvider;
import 'drift_chat_message_store.dart';

export 'local_message_search.dart';

part 'chat_message_export.dart';

/// Local retention backstop: the most messages one conversation keeps on the
/// device.
///
/// This is NOT the retention policy and must not be read as one. The phone is
/// the archive and deliberately outlives the server, which keeps 120 days —
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

  final deletions = ChatDeletionFilter();
  bool deletionCleanupComplete = false;
  final int keepPerConversation;
  final DriftChatMessageStore _drift;
  final AndroidChatMessageStore? _android;

  Future<List<ChatMessage>> page(
    String conversationId, {
    int limit = diskPageSize,
    int? beforeMs,
    String? beforeId,
    String? threadRootId,
  }) async => deletions.filter(
    await _page(
      conversationId,
      limit: limit,
      beforeMs: beforeMs,
      beforeId: beforeId,
      threadRootId: threadRootId,
    ),
  );

  Future<List<ChatMessage>> _page(
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
      if (!_migratedScopes.contains(scope)) {
        if (await native.isLegacyMigrated(scope)) {
          _migratedScopes.add(scope);
        } else {
          // Every write lands in both stores, so Drift already holds this
          // page. Answer from it now and carry the scope across in the
          // background: migrating first cost a 2 000-row read and write on
          // the first open of every chat, which is exactly when the reader
          // is waiting.
          _migrateScope(native, scope, conversationId, threadRootId);
          return await _drift.page(
            conversationId,
            limit: limit,
            beforeMs: beforeMs,
            beforeId: beforeId,
            threadRootId: threadRootId,
          );
        }
      }
      return await native.page(
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

  /// Scopes known to be migrated this session — spares a platform call on
  /// every page read once the answer is yes.
  final _migratedScopes = <String>{};
  final _migrations = <String, Future<void>>{};

  void _migrateScope(
    AndroidChatMessageStore native,
    String scope,
    String conversationId,
    String? threadRootId,
  ) {
    _migrations[scope] ??= () async {
      try {
        // Migrate the entire retained slice before marking this scope done.
        // Re-running after a crash is harmless because id is the conflict key.
        final legacy = await _drift.page(
          conversationId,
          limit: localPageCeiling,
          threadRootId: threadRootId,
        );
        await native.migrateLegacy(scope, legacy);
        _migratedScopes.add(scope);
      } catch (_) {
        // Drift keeps answering this scope; the next open tries again.
      } finally {
        _migrations.remove(scope);
      }
    }();
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

  Future<void> saveRecovered(
    List<ChatMessage> messages, {
    required bool fromBackup,
  }) async {
    messages = deletions.filter(
      messages.where((m) => !m.contentPurged).toList(),
    );
    final before = deletions.revision;
    final native = _android;
    if (native != null) {
      await native.upsert(
        messages,
        recoverySource: fromBackup ? 'backup' : 'server',
      );
    }
    await _drift.saveRecovered(
      deletions.filter(messages),
      fromBackup: fromBackup,
    );
    if (before != deletions.revision) deletionCleanupComplete = false;
  }

  Future<void> saveAll(List<ChatMessage> messages) async {
    messages = deletions.filter(messages);
    final deletionRevision = deletions.revision;
    final native = _android;
    if (native != null) {
      try {
        await native.upsert(messages);
      } catch (_) {
        // Drift below remains a safe write path if the platform store fails.
      }
    }
    await _drift.saveAll(deletions.filter(messages));
    if (deletionRevision != deletions.revision) deletionCleanupComplete = false;
  }

  Future<void> saveOne(ChatMessage message) => saveAll([message]);

  /// Writes [messages] and throws unless every store this phone reads from
  /// now holds them. This is the only write that may be followed by telling
  /// the server "this device has it" (a delivered receipt, private-chat
  /// custody): the server may delete its copy on that word.
  ///
  /// Both stores must succeed on Android. Reads answer from SQLCipher once a
  /// conversation is migrated and from Drift before that, so a row in only
  /// one of them can be invisible.
  ///
  /// A message this phone deliberately deleted is not written and does not
  /// fail the call: nothing is owed for it.
  Future<void> saveDurable(List<ChatMessage> messages) async {
    final kept = deletions.filter(messages);
    final deletionRevision = deletions.revision;
    // Both are attempted even when the first fails: a broken SQLCipher store
    // must not also cost the Drift copy the best-effort path always wrote.
    Object? failure;
    StackTrace? failureTrace;
    try {
      await _android?.upsert(kept);
    } catch (e, st) {
      failure = e;
      failureTrace = st;
    }
    await _drift.saveAllOrThrow(kept);
    if (deletionRevision != deletions.revision) deletionCleanupComplete = false;
    if (failure != null) Error.throwWithStackTrace(failure, failureTrace!);
  }

  /// One settled message by server id from this phone's history, or null —
  /// how a private-chat op finds its target and a private quote its original
  /// after the server has let both go (server 0160). A message deleted here
  /// stays deleted.
  Future<ChatMessage?> byId(String messageId) async {
    final found = await _drift.byId(messageId);
    if (found == null) return null;
    final kept = deletions.filter([found]);
    return kept.isEmpty ? null : kept.first;
  }

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
    Object? failure;
    if (_android != null) {
      try {
        await _android.remove(messageId);
      } catch (e) {
        failure = e;
      }
    }
    await _drift.remove(messageId);
    if (failure != null) throw failure;
  }

  Future<List<ChatMessage>> deletionPage({
    int? afterMs,
    String? afterId,
    bool rollback = false,
  }) => rollback
      ? _drift.exportPage(
          afterMs: afterMs,
          afterId: afterId,
          limit: localPageCeiling,
        )
      : exportPage(afterMs: afterMs, afterId: afterId);

  Future<List<ChatMessage>> search(
    String query, {
    int limit = 30,
    String? conversationId,
  }) async => deletions.filter(
    await _drift.search(query, limit: limit, conversationId: conversationId),
  );

  Future<List<ChatMessage>> encryptedPage({
    int limit = 200,
    int offset = 0,
    String? conversationId,
  }) => _drift.encryptedPage(
    limit: limit,
    offset: offset,
    conversationId: conversationId,
  );

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
      await native.clearAll();
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
