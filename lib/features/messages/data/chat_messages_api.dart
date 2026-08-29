import '../../../core/network/api_client.dart';
import 'models/chat_models.dart';
import 'chat_endpoints.dart';
import 'request_single_flight.dart';

class ChatMessagesApi {
  ChatMessagesApi(this._client, this._endpoints);

  final ApiClient _client;
  final ChatEndpoints _endpoints;
  final RequestSingleFlight<ChatMessagesPage> _pageRequests =
      RequestSingleFlight<ChatMessagesPage>();

  Future<ChatMessagesPage> listMessages(
    String conversationId, {
    String? cursor,
    int? limit,
    String? thread,
  }) {
    final key =
        '$conversationId|${cursor ?? ''}|${limit ?? ''}|${thread ?? ''}';
    return _pageRequests.run(
      key,
      () => _listMessages(
        conversationId,
        cursor: cursor,
        limit: limit,
        thread: thread,
      ),
    );
  }

  Future<ChatMessagesPage> _listMessages(
    String conversationId, {
    String? cursor,
    int? limit,
    String? thread,
  }) async {
    final params = <String, dynamic>{};
    if (cursor != null) params['cursor'] = cursor;
    if (limit != null) params['limit'] = limit;
    if (thread != null) params['thread'] = thread;

    final res = await _client.get(
      _endpoints.messages(conversationId),
      queryParameters: params.isEmpty ? null : params,
    );
    return ChatMessagesPage.fromJson(unwrapApiData<Map<String, dynamic>>(res));
  }

  Future<ChatMessage> sendMessage(
    String conversationId, {
    required String body,
    String? encryptedBody,
    String? encryptionNonce,
    int? encryptionVersion,
    int? encryptionKeyVersion,
    String? parentId,
    List<ChatAttachmentInput> attachments = const [],
    List<String> mentionedUserIds = const [],
  }) async {
    final res = await _client.post(
      _endpoints.messages(conversationId),
      data: {
        'body': body,
        'encrypted_body': ?encryptedBody,
        'encryption_nonce': ?encryptionNonce,
        'encryption_version': ?encryptionVersion,
        'encryption_key_version': ?encryptionKeyVersion,
        'parent_id': ?parentId,
        if (attachments.isNotEmpty)
          'attachments': attachments.map((a) => a.toJson()).toList(),
        if (mentionedUserIds.isNotEmpty) 'mentioned_user_ids': mentionedUserIds,
      },
    );
    return ChatMessage.fromJson(unwrapApiData<Map<String, dynamic>>(res));
  }

  Future<ChatMessage> patchMessage(
    String messageId,
    String body, {
    String? encryptedBody,
    String? encryptionNonce,
    int? encryptionVersion,
    int? encryptionKeyVersion,
  }) async {
    final res = await _client.patch(
      _endpoints.message(messageId),
      data: {
        'body': body,
        'encrypted_body': ?encryptedBody,
        'encryption_nonce': ?encryptionNonce,
        'encryption_version': ?encryptionVersion,
        'encryption_key_version': ?encryptionKeyVersion,
      },
    );
    return ChatMessage.fromJson(unwrapApiData<Map<String, dynamic>>(res));
  }

  Future<void> deleteMessage(String messageId) async {
    await _client.delete(_endpoints.message(messageId));
  }

  Future<List<ChatReactionGroup>> toggleReaction(
    String messageId,
    String emoji,
  ) async {
    final res = await _client.post(
      _endpoints.reactions(messageId),
      data: {'emoji': emoji},
    );
    final data = unwrapApiData<List<dynamic>>(res);
    return data
        .map((e) => ChatReactionGroup.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> markRead(String conversationId) async {
    await _client.post(_endpoints.action(conversationId, 'read'));
  }

  Future<List<ChatMessage>> searchMessages(String q, {int limit = 20}) async {
    final res = await _client.get(
      _endpoints.search,
      queryParameters: {'q': q, 'limit': limit},
    );
    final data = unwrapApiData<List<dynamic>>(res);
    return data
        .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
