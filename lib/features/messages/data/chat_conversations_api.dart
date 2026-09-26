import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../chat-mute/mute_choice.dart';
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

  /// Group identity: name, description, picture, banner — for every group,
  /// a converted workspace channel included.
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

  /// Mute with [choice], or unmute when it is null (server 0162). The answer
  /// carries the end time the server settled on, which is what gets cached.
  Future<MuteResult> setMute(String conversationId, MuteChoice? choice) async {
    final res = await _client.post(
      _endpoints.action(conversationId, 'mute'),
      data: choice?.toBody() ?? {'muted': false},
    );
    final data = unwrapApiData<Map<String, dynamic>>(res);
    return MuteResult.fromJson(data);
  }

  /// Pin or unpin for this account. A fifth pin comes back as 409
  /// `chat_pin_limit`, which the caller shows rather than swallowing: a pin
  /// that silently did nothing is indistinguishable from a broken button.
  Future<bool> pinConversation(String conversationId, bool pinned) async {
    final res = await _client.post(
      _endpoints.action(conversationId, 'pin'),
      data: {'pinned': pinned},
    );
    final data = unwrapApiData<Map<String, dynamic>>(res);
    return data['pinned'] as bool? ?? pinned;
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
