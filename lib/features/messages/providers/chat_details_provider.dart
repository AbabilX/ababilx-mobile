import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../data/chat_details_api.dart';
import '../data/chat_endpoints.dart';
import '../data/models/chat_models.dart';

/// Details reads go through the same `/api/chat/*` routes as the rest of chat.
final chatDetailsApiProvider = Provider<ChatDetailsApi>((ref) {
  return ChatDetailsApi(ref.watch(apiClientProvider), const ChatEndpoints());
});

/// First page only — the details screen shows a strip, and "See all" opens the
/// grid screen which pages on its own.
final chatSharedMediaProvider = FutureProvider.autoDispose
    .family<ChatMediaPage, String>((ref, conversationId) {
      return ref
          .watch(chatDetailsApiProvider)
          .listMedia(conversationId, limit: 12);
    });

final chatGroupsInCommonProvider = FutureProvider.autoDispose
    .family<ChatGroupsInCommon, String>((ref, userId) {
      return ref.watch(chatDetailsApiProvider).groupsInCommon(userId);
    });
