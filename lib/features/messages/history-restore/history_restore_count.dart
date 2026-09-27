import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/first_load_timeout.dart';

/// How many messages the restore of [conversationIds] will save, counted by
/// the server with the rules the walk itself follows (visible rows, threads
/// only under a root with a live reply, content-purged rows left out). Null
/// when it cannot say — an older server or no connection — and the banner
/// then shows the running count alone.
Future<int?> fetchRestoreMessageTotal(
  Ref ref,
  List<String> conversationIds,
) async {
  if (conversationIds.isEmpty) return 0;
  try {
    final response = await ref
        .read(apiClientProvider)
        .post(
          ApiConstants.chatRestoreMessageCount,
          data: {'conversation_ids': conversationIds},
        )
        .timeout(firstLoadNetworkTimeout);
    final data = unwrapApiData<Map<String, dynamic>>(response);
    return (data['total'] as num?)?.toInt();
  } catch (_) {
    return null;
  }
}
