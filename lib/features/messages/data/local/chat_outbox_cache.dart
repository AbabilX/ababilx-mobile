import 'dart:convert';

import 'package:drift/drift.dart' show Value, OrderingTerm;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat_attachment.dart';
import 'chat_local_db.dart';
import 'chat_sidebar_cache.dart' show chatLocalDbProvider;

/// A not-yet-confirmed send, reloaded from disk. Enough to rebuild the
/// pending bubble and to retry the send outright.
///
/// [body] is the plain text for a channel message; for a DM it is empty and
/// [encryptedBody]/[encryptionNonce]/[encryptionKeyVersion] carry the already
/// -sealed envelope instead — plaintext DM text is never written to disk.
class OutboxEntry {
  const OutboxEntry({
    required this.clientRef,
    required this.conversationId,
    required this.body,
    required this.parentId,
    required this.attachments,
    required this.mentionedUserIds,
    required this.createdAtMs,
    this.encryptedBody,
    this.encryptionNonce,
    this.encryptionKeyVersion,
  });

  final String clientRef;
  final String conversationId;
  final String body;
  final String? parentId;
  final List<ChatAttachmentInput> attachments;
  final List<String> mentionedUserIds;
  final int createdAtMs;
  final String? encryptedBody;
  final String? encryptionNonce;
  final int? encryptionKeyVersion;

  bool get isEncrypted => encryptedBody != null && encryptionNonce != null;
}

/// Durable outbox for outbound sends — channel messages in plain text, DM
/// messages as ciphertext only (see [PendingOutboxMessages]). A save is a
/// delivery prerequisite and therefore propagates storage errors. Reads and
/// cleanup remain best-effort because server-confirmed state is recoverable.
class ChatOutboxCache {
  ChatOutboxCache(this._db);

  final ChatLocalDb _db;

  Future<void> save({
    required String clientRef,
    required String conversationId,
    required String body,
    String? parentId,
    List<ChatAttachmentInput> attachments = const [],
    List<String> mentionedUserIds = const [],
    String? encryptedBody,
    String? encryptionNonce,
    int? encryptionKeyVersion,
  }) async {
    await _db
        .into(_db.pendingOutboxMessages)
        .insertOnConflictUpdate(
          PendingOutboxMessagesCompanion.insert(
            clientRef: clientRef,
            conversationId: conversationId,
            body: body,
            parentId: Value(parentId),
            attachmentsJson: jsonEncode(
              attachments.map((a) => a.toJson()).toList(),
            ),
            mentionedUserIdsJson: jsonEncode(mentionedUserIds),
            createdAtMs: DateTime.now().millisecondsSinceEpoch,
            encryptedBody: Value(encryptedBody),
            encryptionNonce: Value(encryptionNonce),
            encryptionKeyVersion: Value(encryptionKeyVersion),
          ),
        );
  }

  Future<void> remove(String clientRef) async {
    try {
      await (_db.delete(
        _db.pendingOutboxMessages,
      )..where((t) => t.clientRef.equals(clientRef))).go();
    } catch (_) {}
  }

  /// All outstanding sends, oldest first, across every conversation.
  Future<List<OutboxEntry>> readAll() async {
    try {
      final rows = await (_db.select(
        _db.pendingOutboxMessages,
      )..orderBy([(t) => OrderingTerm.asc(t.createdAtMs)])).get();
      return rows.map(_toEntry).toList();
    } catch (_) {
      return const [];
    }
  }

  /// Drops the queue for one conversation. A chat the user just deleted must
  /// not keep a pending send alive — it would land in a conversation they
  /// expect gone and drag it back into the sidebar.
  Future<void> removeConversation(String conversationId) async {
    try {
      await (_db.delete(
        _db.pendingOutboxMessages,
      )..where((t) => t.conversationId.equals(conversationId))).go();
    } catch (_) {}
  }

  Future<void> clearAll() async {
    try {
      await _db.delete(_db.pendingOutboxMessages).go();
    } catch (_) {}
  }

  OutboxEntry _toEntry(PendingOutboxMessage row) {
    List<ChatAttachmentInput> attachments = const [];
    List<String> mentionedUserIds = const [];
    try {
      attachments = (jsonDecode(row.attachmentsJson) as List<dynamic>)
          .map((e) => ChatAttachmentInput.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {}
    try {
      mentionedUserIds = (jsonDecode(row.mentionedUserIdsJson) as List<dynamic>)
          .cast<String>();
    } catch (_) {}
    return OutboxEntry(
      clientRef: row.clientRef,
      conversationId: row.conversationId,
      body: row.body,
      parentId: row.parentId,
      attachments: attachments,
      mentionedUserIds: mentionedUserIds,
      createdAtMs: row.createdAtMs,
      encryptedBody: row.encryptedBody,
      encryptionNonce: row.encryptionNonce,
      encryptionKeyVersion: row.encryptionKeyVersion,
    );
  }
}

final chatOutboxCacheProvider = Provider<ChatOutboxCache>((ref) {
  return ChatOutboxCache(ref.watch(chatLocalDbProvider));
});
