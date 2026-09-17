import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import 'ghost_session.dart';

/// Why the server refused, as a stable code for the UI to phrase.
class GhostApiError implements Exception {
  const GhostApiError(this.code, [this.status]);
  final String code;
  final int? status;

  static GhostApiError from(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      final code = data is Map ? data['error']?.toString() : null;
      return GhostApiError(
        code ?? 'ghost_chat_failed',
        error.response?.statusCode,
      );
    }
    return const GhostApiError('ghost_chat_failed');
  }

  @override
  String toString() => 'GhostApiError($code, $status)';
}

class GhostApi {
  const GhostApi(this._client);
  final ApiClient _client;

  Future<GhostSessionGrant> start(String conversationId, int keyVersion) =>
      _grant(
        () => _client.post(
          ApiConstants.ghostChatStart(conversationId),
          data: {'key_version': keyVersion},
        ),
      );

  Future<GhostSessionGrant> accept(String sessionId) =>
      _grant(() => _action(sessionId, 'accept'));

  Future<GhostSession> get(String sessionId) async {
    try {
      final res = await _client.get(ApiConstants.ghostChatSession(sessionId));
      final data = unwrapApiData<Map<String, dynamic>>(res);
      return GhostSession.fromJson(
        Map<String, dynamic>.from(data['session'] as Map? ?? const {}),
      );
    } catch (e) {
      throw GhostApiError.from(e);
    }
  }

  /// decline | cancel | end. The server picks the recorded reason from the
  /// session's state; [reason] only matters for an active session.
  Future<void> finish(String sessionId, String action, {String? reason}) async {
    try {
      await _action(sessionId, action, reason: reason);
    } catch (e) {
      throw GhostApiError.from(e);
    }
  }

  Future<void> heartbeat(String sessionId) => finish(sessionId, 'heartbeat');

  Future<Response<dynamic>> _action(
    String sessionId,
    String action, {
    String? reason,
  }) => _client.post(
    ApiConstants.ghostChatActions(sessionId),
    data: {'action': action, 'reason': ?reason},
  );

  Future<GhostSessionGrant> _grant(
    Future<Response<dynamic>> Function() call,
  ) async {
    try {
      final res = await call();
      return GhostSessionGrant.fromJson(
        unwrapApiData<Map<String, dynamic>>(res),
      );
    } catch (e) {
      throw GhostApiError.from(e);
    }
  }
}

final ghostApiProvider = Provider<GhostApi>(
  (ref) => GhostApi(ref.watch(apiClientProvider)),
);
