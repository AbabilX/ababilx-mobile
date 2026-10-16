import 'package:dio/dio.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import 'models/group_call.dart';
import 'models/group_call_session.dart';

/// Server-side rejection carrying the machine code (`group_call_full`, …) so
/// the UI can phrase it the way web does in `group-call-state.ts`.
class GroupCallApiException implements Exception {
  const GroupCallApiException(this.code);
  final String code;

  @override
  String toString() => 'GroupCallApiException($code)';
}

class GroupCallApi {
  const GroupCallApi(this._client);

  final ApiClient _client;

  /// The active call in a channel, or null when nobody is calling.
  Future<GroupCall?> active(String conversationId) async {
    final response = await _guard(
      () => _client.get(ApiConstants.chatGroupCall(conversationId)),
    );
    return _callOf(response);
  }

  /// [ring] is who a NEW call rings: null = every member (the old body),
  /// empty = nobody. Ignored by the server when the call is already running.
  Future<GroupCallSession> join(
    String conversationId, {
    List<String>? ring,
  }) async {
    final response = await _guard(
      () => _client.post(
        ApiConstants.chatGroupCallJoin(conversationId),
        data: ring == null ? null : {'ring': ring},
      ),
    );
    return GroupCallSession.fromJson(
      unwrapApiData<Map<String, dynamic>>(response),
    );
  }

  Future<GroupCall?> leave(String callId) async {
    final response = await _guard(
      () => _client.post(ApiConstants.chatGroupCallLeave(callId)),
    );
    return _callOf(response);
  }

  /// [action] is `claim` or `release`. Only one member may share at a time.
  Future<GroupCall?> screenShare(String callId, String action) async {
    final response = await _guard(
      () => _client.post(
        ApiConstants.chatGroupCallScreenShare(callId),
        data: {'action': action},
      ),
    );
    return _callOf(response);
  }

  GroupCall? _callOf(Response response) {
    final data = unwrapApiData<Map<String, dynamic>?>(response);
    final call = data?['call'];
    if (call is! Map) return null;
    return GroupCall.fromJson(Map<String, dynamic>.from(call));
  }

  /// Turns the 409/503 bodies into a typed code; anything else bubbles as-is.
  Future<Response> _guard(Future<Response> Function() request) async {
    try {
      return await request();
    } on DioException catch (error) {
      final body = error.response?.data;
      final code = body is Map ? body['error']?.toString() : null;
      if (code != null && code.isNotEmpty) {
        throw GroupCallApiException(code);
      }
      rethrow;
    }
  }
}
