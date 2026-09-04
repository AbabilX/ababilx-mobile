import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import 'chat_endpoints.dart';

class ChatE2eeApi {
  const ChatE2eeApi(this._client, this._endpoints);
  final ApiClient _client;
  final ChatEndpoints _endpoints;

  Future<Map<String, dynamic>> getVault() async {
    final res = await _client.get(ApiConstants.chatE2eeVault);
    return unwrapApiData<Map<String, dynamic>>(res);
  }

  Future<void> putVault(Map<String, dynamic> data) =>
      _client.put(ApiConstants.chatE2eeVault, data: data);

  /// Publishes a device-local identity: the public key and nothing else. The
  /// private half is generated on this phone and never leaves it, which is why
  /// there is no PIN to choose.
  Future<void> putIdentity(Map<String, dynamic> publicJwk) =>
      _client.put(ApiConstants.chatE2eeVault, data: {'public_key': publicJwk});

  Future<void> deleteWrappedKey() =>
      _client.delete(ApiConstants.chatE2eeWrappedKey);

  Future<Map<String, dynamic>> createLink(String deviceName) async {
    final res = await _client.post(
      ApiConstants.chatE2eeLink,
      data: {'device_name': deviceName},
    );
    return unwrapApiData<Map<String, dynamic>>(res);
  }

  Future<Map<String, dynamic>> inspectLink(String token) async {
    final res = await _client.post(
      ApiConstants.chatE2eeLinkInfo,
      data: {'token': token},
    );
    return unwrapApiData<Map<String, dynamic>>(res);
  }

  Future<void> approveLink(String token, Map<String, dynamic> envelope) =>
      _client.post(
        ApiConstants.chatE2eeLinkApprove,
        data: {'token': token, 'identity_envelope': envelope},
      );

  Future<void> denyLink(String token) =>
      _client.post(ApiConstants.chatE2eeLinkDeny, data: {'token': token});

  /// Polling returns the whole envelope, so the raw response is handed back
  /// rather than unwrapped: `status` sits beside `data`, not inside it.
  Future<Map<String, dynamic>> pollLink(String token) async {
    final res = await _client.post(
      ApiConstants.chatE2eeLinkPoll,
      data: {'token': token},
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> getPublicKey(String userId) async {
    final res = await _client.get(_endpoints.publicKey(userId));
    return unwrapApiData<Map<String, dynamic>>(res);
  }

  Future<Map<String, dynamic>> getConversationKey(String conversationId) async {
    final res = await _client.get(
      _endpoints.action(conversationId, 'e2ee-key'),
    );
    return unwrapApiData<Map<String, dynamic>>(res);
  }

  Future<Map<String, dynamic>> createConversationKey(
    String conversationId,
    Map<String, dynamic> envelopes,
  ) async {
    final res = await _client.post(
      _endpoints.action(conversationId, 'e2ee-key'),
      data: {'envelopes': envelopes},
    );
    return unwrapApiData<Map<String, dynamic>>(res);
  }
}
