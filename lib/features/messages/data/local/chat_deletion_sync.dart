import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../attachments/providers/attachment_providers.dart';
import 'chat_message_store.dart';
import 'chat_message_row.dart';
import 'chat_outbox_cache.dart';
import 'chat_sidebar_cache.dart';

/// Apply the full server snapshot before replaying the outbox or restoring a backup.
Future<void> syncChatDeletions(Ref ref, String userId) async {
  if (userId.isEmpty) return;
  final store = ref.read(chatMessageStoreProvider);
  await store.deletions.load(userId);
  final response = await ref
      .read(apiClientProvider)
      .get(ApiConstants.chatDeletions);
  final next = unwrapApiData<List<dynamic>>(
    response,
  ).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  final before = jsonEncode(store.deletions.records);
  await store.deletions.replace(next);
  final changed = before != jsonEncode(store.deletions.records);
  // Also retry unfinished cleanup after a process restart.
  if (!changed && store.deletionCleanupComplete) return;
  store.deletionCleanupComplete = false;
  if (store.deletions.records.isEmpty) {
    store.deletionCleanupComplete = true;
    return;
  }
  for (final rollback in [false, true]) {
    int? afterMs;
    String? afterId;
    while (true) {
      final page = await store.deletionPage(
        afterMs: afterMs,
        afterId: afterId,
        rollback: rollback,
      );
      if (page.isEmpty) break;
      for (final message in page) {
        if (!store.deletions.allows(message)) {
          await ref
              .read(attachmentSweeperProvider)
              .onMessageDeleted(message.id);
          await store.remove(message.id);
        }
      }
      afterMs = DateTime.parse(page.last.createdAt).millisecondsSinceEpoch;
      afterId = localMessageRowId(page.last);
    }
  }
  final outbox = ChatOutboxCache(ref.read(chatLocalDbProvider));
  for (final entry in await outbox.readAll()) {
    if (!store.deletions.allowsTime(
      entry.conversationId,
      entry.createdAtMs * 1000,
      pending: true,
    )) {
      await outbox.remove(entry.clientRef);
    }
  }
  store.deletionCleanupComplete = true;
}
