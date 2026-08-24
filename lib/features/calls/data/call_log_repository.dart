import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../messages/data/chat_endpoints.dart';
import '../../profile/providers/profile_provider.dart';
import 'models/call_log_entry.dart';

/// Reads call history. Which path it hits follows the same capability rule as
/// the rest of chat: the independent route when the account has team-less
/// messaging (every call, personal and workspace), the workspace route
/// otherwise (that workspace's calls).
class CallLogRepository {
  const CallLogRepository(this._client, this._endpoints);

  final ApiClient _client;
  final ChatEndpoints _endpoints;

  Future<CallLogPage> page({String? before, int limit = 50}) async {
    final res = await _client.get(
      _endpoints.callLog,
      queryParameters: {'limit': limit, 'before': ?before},
    );
    return CallLogPage.fromJson(unwrapApiData<Map<String, dynamic>>(res));
  }
}

final callLogRepositoryProvider = Provider<CallLogRepository>((ref) {
  final independent =
      ref.watch(profileProvider).valueOrNull?.independentChat ?? false;
  return CallLogRepository(
    ref.watch(apiClientProvider),
    ChatEndpoints(independent: independent),
  );
});
