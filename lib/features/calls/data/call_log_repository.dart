import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../messages/data/chat_endpoints.dart';
import 'models/call_log_entry.dart';

/// Reads call history. Which path it hits follows the same capability rule as
/// the rest of chat: the independent route when the account has team-less
/// messaging (every call, personal and workspace), the workspace route
/// otherwise (that workspace's calls).
class CallLogRepository {
  const CallLogRepository(this._client, this._endpoints);

  final ApiClient _client;
  final ChatEndpoints _endpoints;

  /// A 404 is answered with an empty page, not an error. A server that
  /// predates this endpoint — or one running with independent chat off while
  /// the client asks for the personal route — has no history to give, and the
  /// failure screen tells the user to check a connection that is fine.
  Future<CallLogPage> page({String? before, int limit = 50}) async {
    try {
      final res = await _client.get(
        _endpoints.callLog,
        queryParameters: {'limit': limit, 'before': ?before},
      );
      return CallLogPage.fromJson(unwrapApiData<Map<String, dynamic>>(res));
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (status == 404) {
        return const CallLogPage(calls: [], nextCursor: '');
      }
      // Carry the server's own message instead of Dio's generic "bad
      // response". Our handlers answer a failure with {error: "..."}, and
      // that sentence is the whole diagnosis — the status code alone says
      // only that something went wrong somewhere.
      final body = error.response?.data;
      final detail = body is Map ? body['error']?.toString() : null;
      if (detail != null) throw Exception('HTTP $status: $detail');
      rethrow;
    }
  }
}

final callLogRepositoryProvider = Provider<CallLogRepository>((ref) {
  return CallLogRepository(ref.watch(apiClientProvider), const ChatEndpoints());
});
