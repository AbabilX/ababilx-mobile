import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
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

  Future<List<ChatConnection>> listConnections() async {
    final response = await _client.get(ApiConstants.independentChatConnections);
    final data = unwrapApiData<Map<String, dynamic>>(response);
    return _connections(data['connections']);
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
