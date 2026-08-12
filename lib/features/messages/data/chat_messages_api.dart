import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import 'models/chat_models.dart';

class ChatMessagesApi {
  const ChatMessagesApi(this._client);

  final ApiClient _client;

  Future<ChatMessagesPage> listMessages(
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
      ApiConstants.chatMessages(conversationId),
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
      ApiConstants.chatMessages(conversationId),
      data: {
        'body': body,
        if (encryptedBody != null) 'encrypted_body': encryptedBody,
        if (encryptionNonce != null) 'encryption_nonce': encryptionNonce,
        if (encryptionVersion != null) 'encryption_version': encryptionVersion,
        if (encryptionKeyVersion != null)
          'encryption_key_version': encryptionKeyVersion,
        if (parentId != null) 'parent_id': parentId,
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
      ApiConstants.chatMessage(messageId),
      data: {
        'body': body,
        if (encryptedBody != null) 'encrypted_body': encryptedBody,
        if (encryptionNonce != null) 'encryption_nonce': encryptionNonce,
        if (encryptionVersion != null) 'encryption_version': encryptionVersion,
        if (encryptionKeyVersion != null)
          'encryption_key_version': encryptionKeyVersion,
      },
    );
    return ChatMessage.fromJson(unwrapApiData<Map<String, dynamic>>(res));
  }

  Future<void> deleteMessage(String messageId) async {
    await _client.delete(ApiConstants.chatMessage(messageId));
  }

  Future<List<ChatReactionGroup>> toggleReaction(
    String messageId,
    String emoji,
  ) async {
    final res = await _client.post(
      ApiConstants.chatMessageReactions(messageId),
      data: {'emoji': emoji},
    );
    final data = unwrapApiData<List<dynamic>>(res);
    return data
        .map((e) => ChatReactionGroup.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> markRead(String conversationId) async {
    await _client.post(ApiConstants.chatConversationRead(conversationId));
  }

  Future<List<ChatMessage>> searchMessages(String q, {int limit = 20}) async {
    final res = await _client.get(
      ApiConstants.chatSearch,
      queryParameters: {'q': q, 'limit': limit},
    );
    final data = unwrapApiData<List<dynamic>>(res);
    return data
        .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
