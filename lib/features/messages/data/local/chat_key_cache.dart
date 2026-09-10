import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'chat_local_db.dart';
import 'chat_sidebar_cache.dart' show chatLocalDbProvider;

/// One conversation key envelope as this device stores it.
class CachedKeyEnvelope {
  const CachedKeyEnvelope({required this.version, required this.envelope});
  final int version;
  final Map<String, dynamic> envelope;
}

/// Durable home for the sealed conversation-key envelopes this device has been
/// given — see [CachedConversationKeys] for why it exists and why storing this
/// puts nothing readable on disk.
///
/// It stores envelopes, never opened keys: the plaintext key stays in memory
/// for the life of the process, exactly as before.
class ChatKeyCache {
  ChatKeyCache(this._db);

  final ChatLocalDb _db;

  Future<void> save(
    String conversationId,
    int version,
    Map<String, dynamic> envelope,
  ) async {
    if (conversationId.isEmpty) return;
    await _db
        .into(_db.cachedConversationKeys)
        .insertOnConflictUpdate(
          CachedConversationKeysCompanion.insert(
            conversationId: conversationId,
            keyVersion: version,
            envelopeJson: jsonEncode(envelope),
            updatedAtMs: DateTime.now().millisecondsSinceEpoch,
          ),
        );
  }

  /// The envelope for one exact version, or null. A row that no longer decodes
  /// is a cache miss, the same rule [messageFromRow] follows.
  Future<Map<String, dynamic>?> read(String conversationId, int version) async {
    final row =
        await (_db.select(_db.cachedConversationKeys)..where(
              (t) =>
                  t.conversationId.equals(conversationId) &
                  t.keyVersion.equals(version),
            ))
            .getSingleOrNull();
    if (row == null) return null;
    try {
      return Map<String, dynamic>.from(
        jsonDecode(row.envelopeJson) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  /// The newest version this device holds for a conversation. Used where a
  /// message carries no key version of its own to aim at.
  Future<CachedKeyEnvelope?> newest(String conversationId) async {
    final row =
        await (_db.select(_db.cachedConversationKeys)
              ..where((t) => t.conversationId.equals(conversationId))
              ..orderBy([
                (t) => OrderingTerm(
                  expression: t.keyVersion,
                  mode: OrderingMode.desc,
                ),
              ])
              ..limit(1))
            .getSingleOrNull();
    if (row == null) return null;
    try {
      return CachedKeyEnvelope(
        version: row.keyVersion,
        envelope: Map<String, dynamic>.from(
          jsonDecode(row.envelopeJson) as Map<String, dynamic>,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> remove(String conversationId, int version) =>
      (_db.delete(_db.cachedConversationKeys)..where(
            (t) =>
                t.conversationId.equals(conversationId) &
                t.keyVersion.equals(version),
          ))
          .go();

  Future<void> clearConversation(String conversationId) => (_db.delete(
    _db.cachedConversationKeys,
  )..where((t) => t.conversationId.equals(conversationId))).go();

  Future<void> clearAll() => _db.delete(_db.cachedConversationKeys).go();
}

final chatKeyCacheProvider = Provider<ChatKeyCache>(
  (ref) => ChatKeyCache(ref.watch(chatLocalDbProvider)),
);
