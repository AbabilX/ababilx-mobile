import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat_models.dart';
import 'chat_local_db.dart';

/// Cache-first sidebar: read instantly, write after network refresh.
class ChatSidebarCache {
  ChatSidebarCache(this._db);

  final ChatLocalDb _db;

  Future<ChatSidebar?> read(String userId) async {
    if (userId.isEmpty) return null;
    final row = await (_db.select(_db.cachedSidebars)
          ..where((t) => t.userId.equals(userId)))
        .getSingleOrNull();
    if (row == null) return null;
    try {
      final map = jsonDecode(row.payloadJson) as Map<String, dynamic>;
      return ChatSidebar.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String userId, ChatSidebar sidebar) async {
    if (userId.isEmpty) return;
    await _db.into(_db.cachedSidebars).insertOnConflictUpdate(
          CachedSidebarsCompanion.insert(
            userId: userId,
            payloadJson: jsonEncode(sidebar.toJson()),
            updatedAtMs: DateTime.now().millisecondsSinceEpoch,
          ),
        );
  }

  Future<void> clearAll() async {
    await _db.delete(_db.cachedSidebars).go();
  }

  Future<void> clearUser(String userId) async {
    if (userId.isEmpty) return;
    await (_db.delete(_db.cachedSidebars)
          ..where((t) => t.userId.equals(userId)))
        .go();
  }
}

final chatLocalDbProvider = Provider<ChatLocalDb>((ref) {
  final db = ChatLocalDb();
  ref.onDispose(db.close);
  return db;
});

final chatSidebarCacheProvider = Provider<ChatSidebarCache>((ref) {
  return ChatSidebarCache(ref.watch(chatLocalDbProvider));
});
