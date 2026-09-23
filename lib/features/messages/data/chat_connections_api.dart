import 'dart:async';

import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/first_load_timeout.dart';
import 'models/chat_connection.dart';

class ChatConnectionsApi {
  const ChatConnectionsApi(this._client);

  final ApiClient _client;

  Future<ChatUserSearchResult> search(String query, {int limit = 20}) async {
    final response = await _client.get(
      ApiConstants.independentChatUsersSearch,
      queryParameters: {'query': query, 'limit': limit},
    );
    final data = unwrapApiData<Map<String, dynamic>>(response);
    return ChatUserSearchResult(
      matchedBy: data['matched_by'] as String? ?? '',
      users: _users(data['users']),
    );
  }

  /// Resolves one exact handle — what a scanned QR code carries — or null
  /// when nobody holds it.
  ///
  /// Not the search endpoint: search is a prefix match gated by the person's
  /// username-discovery toggle, which is off by default, so a QR code routed
  /// through it would find almost nobody. A full handle shown by its owner is
  /// exact, and the server treats it that way.
  Future<ChatUserSummary?> lookupByUsername(String username) async {
    try {
      final response = await _client.get(ApiConstants.chatHandle(username));
      final data = unwrapApiData<Map<String, dynamic>>(response);
      final user = data['user'];
      if (user is! Map) return null;
      return ChatUserSummary.fromJson(Map<String, dynamic>.from(user));
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<List<ChatConnection>> listConnections() async {
    final cancel = CancelToken();
    final response = await _client
        .get(ApiConstants.independentChatConnections, cancelToken: cancel)
        .timeout(
          firstLoadNetworkTimeout,
          onTimeout: () {
            cancel.cancel('connections-timeout');
            throw TimeoutException('connections', firstLoadNetworkTimeout);
          },
        );
    final data = unwrapApiData<dynamic>(response);
    final map = data is Map
        ? Map<String, dynamic>.from(data)
        : const <String, dynamic>{};
    return _connections(map['connections']);
  }

  Future<List<ChatConnection>> listBlocked() async {
    final response = await _client.get(ApiConstants.independentChatBlocked);
    final data = unwrapApiData<Map<String, dynamic>>(response);
    return _connections(data['blocked']);
  }

  Future<ChatConnectionRequests> listRequests() async {
    final response = await _client.get(
      ApiConstants.independentChatConnectionRequests,
    );
    final data = unwrapApiData<Map<String, dynamic>>(response);
    return ChatConnectionRequests(
      incoming: _connections(data['requests']),
      sent: _connections(data['sent']),
    );
  }

  Future<void> sendRequest(String userId) async {
    await _client.post(
      ApiConstants.independentChatConnectionRequests,
      data: {'user_id': userId},
    );
  }

  Future<void> respond(String requestId, {required bool accept}) async {
    await _client.post(
      ApiConstants.independentChatConnectionRequestAction(
        requestId,
        accept ? 'accept' : 'reject',
      ),
    );
  }

  Future<void> block(String userId) => _client.post(
    '${ApiConstants.independentChatConnectionUser(userId)}/block',
  );

  Future<void> remove(String userId) =>
      _client.delete(ApiConstants.independentChatConnectionUser(userId));

  List<ChatConnection> _connections(dynamic raw) => (raw as List? ?? const [])
      .whereType<Map>()
      .map((item) => ChatConnection.fromJson(Map<String, dynamic>.from(item)))
      .toList();

  List<ChatUserSummary> _users(dynamic raw) => (raw as List? ?? const [])
      .whereType<Map>()
      .map((item) => ChatUserSummary.fromJson(Map<String, dynamic>.from(item)))
      .toList();
}
