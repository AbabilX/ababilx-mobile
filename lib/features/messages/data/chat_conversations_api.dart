import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import 'models/chat_models.dart';
import 'chat_endpoints.dart';

class ChatConversationsApi {
  const ChatConversationsApi(this._client, this._endpoints);

  final ApiClient _client;
  final ChatEndpoints _endpoints;

  Future<ChatSidebar> listConversations() async {
    final res = await _client.get(_endpoints.conversations);
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
      data: {'name': name, 'slug': ?slug, 'is_private': isPrivate},
    );
    return ChatConversation.fromJson(unwrapApiData<Map<String, dynamic>>(res));
  }

  Future<ChatConversation> patchChannel(
    String id, {
    String? name,
    bool? archive,
  }) async {
    final res = await _client.patch(
      _endpoints.action(id, ''),
      data: {'name': ?name, 'archive': ?archive},
    );
    return ChatConversation.fromJson(unwrapApiData<Map<String, dynamic>>(res));
  }

  Future<void> addChannelMember(String channelId, String userId) async {
    await _client.post(
      _endpoints.action(channelId, 'members'),
      data: {'user_id': userId},
    );
  }

  Future<List<ChatMember>> listChannelMembers(String channelId) async {
    final res = await _client.get(_endpoints.action(channelId, 'members'));
    final data = unwrapApiData<List<dynamic>>(res);
    return data
        .map((e) => ChatMember.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Personal-group management. These three hang off `/api/chat/*` on
  /// purpose, not off [ChatEndpoints]: they exist for personal groups only, so
  /// there is no workspace twin to route to.
  ///
  /// Personal-group identity: name, description, picture, banner. Workspace
  /// channels keep [patchChannel] — a channel takes management from its team,
  /// so there is nothing here for it to set.
  ///
  /// An omitted field is left alone and an empty string clears it, which is why
  /// every argument is nullable rather than defaulted.
  Future<ChatConversation> updateGroupInfo(
    String conversationId, {
    String? name,
    String? description,
    String? avatarUrl,
    String? bannerUrl,
  }) async {
    final res = await _client.patch(
      ApiConstants.independentChatConversationAction(conversationId, 'info'),
      data: {
        'name': ?name,
        'description': ?description,
        'avatar_url': ?avatarUrl,
        'banner_url': ?bannerUrl,
      },
    );
    return ChatConversation.fromJson(unwrapApiData<Map<String, dynamic>>(res));
  }

  Future<void> setGroupMemberRole(
    String conversationId,
    String userId,
    String role,
  ) async {
    await _client.put(
      ApiConstants.independentChatConversationAction(
        conversationId,
        'members/$userId/role',
      ),
      data: {'role': role},
    );
  }

  Future<void> removeGroupMember(String conversationId, String userId) async {
    await _client.delete(
      ApiConstants.independentChatConversationAction(
        conversationId,
        'members/$userId',
      ),
    );
  }

  Future<void> leaveChannel(String channelId) async {
    await _client.post(_endpoints.action(channelId, 'leave'));
  }

  Future<void> deleteChannel(String channelId) async {
    await _client.delete(_endpoints.action(channelId, ''));
  }

  Future<ChatConversation> startDm(String userId) async {
    final res = await _client.post(_endpoints.dm, data: {'user_id': userId});
    return ChatConversation.fromJson(unwrapApiData<Map<String, dynamic>>(res));
  }

  /// Forwards one message to prepared destinations.
  ///
  /// [targets] carries the per-destination text and is required whenever
  /// encryption is in play — which is every DM and every personal group. The
  /// server holds only ciphertext sealed under the SOURCE conversation's key,
  /// so it cannot produce the copy a destination needs. The id lists remain
  /// for the one case that does not need it: a plaintext source going to a
  /// workspace channel.
  Future<int> forwardMessage({
    required String messageId,
    List<String>? conversationIds,
    List<String>? userIds,
    List<Map<String, dynamic>>? targets,
    String? caption,
  }) async {
    final res = await _client.post(
      _endpoints.forward,
      data: {
        'message_id': messageId,
        'conversation_ids': ?conversationIds,
        'user_ids': ?userIds,
        'targets': ?targets,
        'caption': ?caption,
      },
    );
    final data = unwrapApiData<Map<String, dynamic>>(res);
    return data['forwarded_to'] as int? ?? 0;
  }

  Future<bool> muteConversation(String conversationId, bool muted) async {
    final res = await _client.post(
      _endpoints.action(conversationId, 'mute'),
      data: {'muted': muted},
    );
    final data = unwrapApiData<Map<String, dynamic>>(res);
    return data['muted'] as bool? ?? muted;
  }

  Future<void> hideDm(String conversationId) async {
    await _client.post(_endpoints.action(conversationId, 'hide'));
  }

  /// Answers an incoming message request without having to reply first.
  Future<void> acceptMessageRequest(String conversationId) async {
    await _client.post(_endpoints.action(conversationId, 'accept'));
  }

  Future<ChatConversation> createPersonalGroup(
    String name,
    List<String> memberIds,
  ) async {
    final res = await _client.post(
      ApiConstants.independentChatGroups,
      data: {'name': name, 'member_ids': memberIds},
    );
    return ChatConversation.fromJson(unwrapApiData<Map<String, dynamic>>(res));
  }
}
