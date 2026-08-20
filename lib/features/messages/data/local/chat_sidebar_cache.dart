import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat_models.dart';
import 'chat_local_db.dart';

/// Cache-first sidebar: read instantly, write after network refresh.
class ChatSidebarCache {
  ChatSidebarCache(this._db);

  final ChatLocalDb _db;

  Future<ChatSidebar?> read(String userId) async {
    if (userId.isEmpty) {
      debugPrint('[ChatCache] read: empty userId, skipping');
      return null;
    }
    final row = await (_db.select(
      _db.cachedSidebars,
    )..where((t) => t.userId.equals(userId))).getSingleOrNull();
    if (row == null) {
      debugPrint('[ChatCache] read: no row for userId=$userId');
      return null;
    }
    try {
      final map = jsonDecode(row.payloadJson) as Map<String, dynamic>;
      final sidebar = ChatSidebar.fromJson(map);
      debugPrint(
        '[ChatCache] read: userId=$userId dms=${sidebar.dms.length} '
        'channels=${sidebar.channels.length}',
      );
      return sidebar;
    } catch (e) {
      debugPrint('[ChatCache] read: decode failed for userId=$userId: $e');
      return null;
    }
  }

  Future<void> write(String userId, ChatSidebar sidebar) async {
    if (userId.isEmpty) {
      debugPrint('[ChatCache] write: empty userId, skipping');
      return;
    }
    try {
      await _db
          .into(_db.cachedSidebars)
          .insertOnConflictUpdate(
            CachedSidebarsCompanion.insert(
              userId: userId,
              payloadJson: jsonEncode(sidebar.toJson()),
              updatedAtMs: DateTime.now().millisecondsSinceEpoch,
            ),
          );
      debugPrint(
        '[ChatCache] write: userId=$userId dms=${sidebar.dms.length} '
        'channels=${sidebar.channels.length}',
      );
    } catch (e) {
      debugPrint('[ChatCache] write: FAILED for userId=$userId: $e');
      rethrow;
    }
  }

  Future<void> clearAll() async {
    await _db.delete(_db.cachedSidebars).go();
  }

  Future<void> clearUser(String userId) async {
    if (userId.isEmpty) return;
    await (_db.delete(
      _db.cachedSidebars,
    )..where((t) => t.userId.equals(userId))).go();
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
