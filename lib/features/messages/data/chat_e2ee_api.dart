import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';

class ChatE2eeApi {
  const ChatE2eeApi(this._client);
  final ApiClient _client;

  Future<Map<String, dynamic>> getVault() async {
    final res = await _client.get(ApiConstants.chatE2eeVault);
    return unwrapApiData<Map<String, dynamic>>(res);
  }

  Future<void> putVault(Map<String, dynamic> data) =>
      _client.put(ApiConstants.chatE2eeVault, data: data);

  Future<Map<String, dynamic>> getPublicKey(String userId) async {
    final res = await _client.get(ApiConstants.chatE2eePublicKey(userId));
    return unwrapApiData<Map<String, dynamic>>(res);
  }

  Future<Map<String, dynamic>> getConversationKey(String conversationId) async {
    final res = await _client.get(
      ApiConstants.chatE2eeConversationKey(conversationId),
    );
    return unwrapApiData<Map<String, dynamic>>(res);
  }

  Future<Map<String, dynamic>> createConversationKey(
    String conversationId,
    Map<String, dynamic> envelopes,
  ) async {
    final res = await _client.post(
      ApiConstants.chatE2eeConversationKey(conversationId),
      data: {'envelopes': envelopes},
    );
    return unwrapApiData<Map<String, dynamic>>(res);
  }
}
