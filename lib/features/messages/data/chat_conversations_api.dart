import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import 'models/chat_models.dart';

class ChatConversationsApi {
  const ChatConversationsApi(this._client);

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

  Future<bool> muteConversation(String conversationId, bool muted) async {
    final res = await _client.post(
      ApiConstants.chatConversationMute(conversationId),
      data: {'muted': muted},
    );
    final data = unwrapApiData<Map<String, dynamic>>(res);
    return data['muted'] as bool? ?? muted;
  }

  Future<void> hideDm(String conversationId) async {
    await _client.post(ApiConstants.chatConversationHide(conversationId));
  }
}
