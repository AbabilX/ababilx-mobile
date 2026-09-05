import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../profile/providers/profile_provider.dart';
import '../data/chat_details_api.dart';
import '../data/chat_endpoints.dart';
import '../data/models/chat_models.dart';

/// Which prefix the details reads use follows the same capability flag the
/// rest of chat follows: `/api/chat/*` when independent messaging is on, the
/// workspace path otherwise. Same handlers behind both.
final chatDetailsApiProvider = Provider<ChatDetailsApi>((ref) {
  final independent =
      ref.watch(profileProvider).valueOrNull?.independentChat ?? false;
  return ChatDetailsApi(
    ref.watch(apiClientProvider),
    ChatEndpoints(independent: independent),
  );
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
