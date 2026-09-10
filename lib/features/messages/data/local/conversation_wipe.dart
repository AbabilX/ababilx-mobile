import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../attachments/storage/storage_providers.dart';
import 'chat_sidebar_cache.dart' show chatLocalDbProvider;
import 'chat_key_cache.dart';
import 'chat_message_store.dart';
import 'chat_outbox_cache.dart';

/// Erases every local trace of a conversation the user deleted.
///
/// The server side of a delete is only half of it. Messages live in a local
/// drift database and their attachments as files in the app's private
/// directory, so a chat deleted in the cloud stayed fully readable offline —
/// and on Android the native store keeps its own copy for drawing
/// notifications, which has to go with the rest.
///
/// Best-effort by design: a failure here must not make the delete itself look
/// like it failed, since the server has already carried it out.
Future<void> wipeConversationLocally(Ref ref, String conversationId) async {
  if (conversationId.isEmpty) return;
  try {
    await ref.read(chatMessageStoreProvider).clearConversation(conversationId);
  } catch (_) {}
  try {
    await ChatOutboxCache(
      ref.read(chatLocalDbProvider),
    ).removeConversation(conversationId);
  } catch (_) {}
  try {
    await ref.read(chatKeyCacheProvider).clearConversation(conversationId);
  } catch (_) {}
  try {
    await ref.read(storageManagerProvider).purgeConversation(conversationId);
  } catch (_) {}
}
