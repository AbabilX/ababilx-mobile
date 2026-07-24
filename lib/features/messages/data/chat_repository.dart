import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import 'models/chat_models.dart';

class ChatRepository {
  const ChatRepository(this._client);
  final ApiClient _client;

  Future<ChatSidebar> listConversations() async {
    final res = await _client.get(ApiConstants.chatConversations);
    final data = unwrapApiData<Map<String, dynamic>>(res);
    return ChatSidebar.fromJson(data);
  }

  Future<ChatConversation> createChannel({
    required String name,
    String? slug,
    bool isPrivate = false,
  }) async {
    final res = await _client.post(
      ApiConstants.chatChannels,
      data: {
        'name': name,
        if (slug != null) 'slug': slug,
        'is_private': isPrivate,
      },
    );
    return ChatConversation.fromJson(unwrapApiData<Map<String, dynamic>>(res));
  }

  Future<ChatConversation> patchChannel(
    String id, {
    String? name,
    bool? archive,
  }) async {
    final res = await _client.patch(
      ApiConstants.chatChannel(id),
      data: {
        if (name != null) 'name': name,
        if (archive != null) 'archive': archive,
      },
    );
    return ChatConversation.fromJson(unwrapApiData<Map<String, dynamic>>(res));
  }

  Future<void> addChannelMember(String channelId, String userId) async {
    await _client.post(
      ApiConstants.chatChannelMembers(channelId),
      data: {'user_id': userId},
    );
  }

  Future<List<ChatMember>> listChannelMembers(String channelId) async {
    final res = await _client.get(ApiConstants.chatChannelMembers(channelId));
    final data = unwrapApiData<List<dynamic>>(res);
    return data
        .map((e) => ChatMember.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> leaveChannel(String channelId) async {
    await _client.post(ApiConstants.chatChannelLeave(channelId));
  }

  Future<void> deleteChannel(String channelId) async {
    await _client.delete(ApiConstants.chatChannel(channelId));
  }

  Future<ChatConversation> startDm(String userId) async {
    final res = await _client.post(
      ApiConstants.chatDm,
      data: {'user_id': userId},
    );
    return ChatConversation.fromJson(unwrapApiData<Map<String, dynamic>>(res));
  }

  Future<int> forwardMessage({
    required String messageId,
    List<String>? conversationIds,
    List<String>? userIds,
    String? caption,
  }) async {
    final res = await _client.post(
      ApiConstants.chatForward,
      data: {
        'message_id': messageId,
        if (conversationIds != null) 'conversation_ids': conversationIds,
        if (userIds != null) 'user_ids': userIds,
        if (caption != null) 'caption': caption,
      },
    );
    final data = unwrapApiData<Map<String, dynamic>>(res);
    return data['forwarded_to'] as int? ?? 0;
  }

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
    String? parentId,
    List<ChatAttachmentInput> attachments = const [],
    List<String> mentionedUserIds = const [],
  }) async {
    final res = await _client.post(
      ApiConstants.chatMessages(conversationId),
      data: {
        'body': body,
        if (parentId != null) 'parent_id': parentId,
        if (attachments.isNotEmpty)
          'attachments': attachments.map((a) => a.toJson()).toList(),
        if (mentionedUserIds.isNotEmpty)
          'mentioned_user_ids': mentionedUserIds,
      },
    );
    return ChatMessage.fromJson(unwrapApiData<Map<String, dynamic>>(res));
  }

  Future<ChatMessage> patchMessage(String messageId, String body) async {
    final res = await _client.patch(
      ApiConstants.chatMessage(messageId),
      data: {'body': body},
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

  Future<bool> muteConversation(String conversationId, bool muted) async {
    final res = await _client.post(
      ApiConstants.chatConversationMute(conversationId),
      data: {'muted': muted},
    );
    final data = unwrapApiData<Map<String, dynamic>>(res);
    return data['muted'] as bool? ?? muted;
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

  Future<ChatPresignResult> presignAttachment(
    String conversationId, {
    required String contentType,
    required String fileName,
    required int sizeBytes,
  }) async {
    final res = await _client.post(
      ApiConstants.chatConversationPresign(conversationId),
      data: {
        'content_type': contentType,
        'file_name': fileName,
        'size_bytes': sizeBytes,
      },
    );
    return ChatPresignResult.fromJson(unwrapApiData<Map<String, dynamic>>(res));
  }

  Future<void> discardUpload(String conversationId, String fileUrl) async {
    await _client.post(
      ApiConstants.chatConversationDiscard(conversationId),
      data: {'file_url': fileUrl},
    );
  }
}

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => ChatRepository(ref.watch(apiClientProvider)),
);
