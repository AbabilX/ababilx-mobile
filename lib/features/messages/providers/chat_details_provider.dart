import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../data/chat_details_api.dart';
import '../data/chat_endpoints.dart';
import '../data/models/chat_models.dart';
import '../message_e2ee/message_vault.dart';
import 'chat_provider.dart';

/// Details reads go through the same `/api/chat/*` routes as the rest of chat.
final chatDetailsApiProvider = Provider<ChatDetailsApi>((ref) {
  return ChatDetailsApi(ref.watch(apiClientProvider), const ChatEndpoints());
});

/// One page of a conversation's shared media, ready to draw.
typedef SharedMediaLoad =
    Future<ChatMediaPage> Function(
      String conversationId, {
      String kind,
      String? cursor,
      int limit,
    });

/// The media listing with every encrypted file's key opened (server 0168).
///
/// The grid shows files this phone may never have had in a timeline, so the
/// listing carries each one's sealed key and it is opened here, the same way
/// a message's attachments are. One that does not open stays a file this
/// device cannot read yet; it is not dropped.
final sharedMediaLoadProvider = Provider<SharedMediaLoad>((ref) {
  return (conversationId, {kind = 'media', cursor, limit = 30}) async {
    final page = await ref
        .read(chatDetailsApiProvider)
        .listMedia(conversationId, kind: kind, cursor: cursor, limit: limit);
    if (!page.items.any((a) => a.needsKey)) return page;
    final userId = await ref.read(chatProvider.notifier).ensureCurrentUserId();
    final vault = ref.read(messageVaultProvider);
    return page.withItems(
      await Future.wait(
        page.items.map(
          (a) => vault.openAttachment(
            conversationId: conversationId,
            currentUserId: userId,
            attachment: a,
          ),
        ),
      ),
    );
  };
});

/// First page only — the details screen shows a strip, and "See all" opens the
/// grid screen which pages on its own.
final chatSharedMediaProvider = FutureProvider.autoDispose
    .family<ChatMediaPage, String>((ref, conversationId) {
      return ref.watch(sharedMediaLoadProvider)(conversationId, limit: 12);
    });

final chatGroupsInCommonProvider = FutureProvider.autoDispose
    .family<ChatGroupsInCommon, String>((ref, userId) {
      return ref.watch(chatDetailsApiProvider).groupsInCommon(userId);
    });
