import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import 'models/chat_models.dart';

/// Webhook feeds: a conversation nobody can post into, filled only by inbound
/// HTTP.
///
/// A feed belongs to the account that made it and starts with its creator
/// alone (migration 0128). There used to be a second, workspace kind under the
/// team prefix; since the server's migration 0145 converted those in place,
/// every feed is this one and every call here takes the `/api/chat/*` path.
class ChatWebhooksApi {
  const ChatWebhooksApi(this._client);

  final ApiClient _client;

  /// Creates the feed and its endpoint in one call. The response is the only
  /// time the secret URL exists.
  ///
  /// A feed takes a name and nothing else: it has no slug, and with no team
  /// there is nobody a "public" feed could be open to.
  Future<({ChatConversation conversation, ChatWebhookCreated created})>
  createWebhookChannel({required String name}) async {
    final res = await _client.post(
      ApiConstants.personalWebhookChannels,
      data: {'name': name},
    );
    final data = unwrapApiData<Map<String, dynamic>>(res);
    return (
      conversation: ChatConversation.fromJson(
        Map<String, dynamic>.from(data['conversation'] as Map? ?? const {}),
      ),
      created: ChatWebhookCreated.fromJson(data),
    );
  }

  /// Mints a new secret and kills the previous one on the same call. There is
  /// no "show me the current URL" endpoint, because the server keeps a hash.
  Future<ChatWebhookCreated> regenerate(String conversationId) async {
    final res = await _client.post(
      ApiConstants.personalWebhookRegenerate(conversationId),
    );
    return ChatWebhookCreated.fromJson(
      unwrapApiData<Map<String, dynamic>>(res),
    );
  }

  /// The feed's own presign, not the conversation attachment one: the server
  /// checks the object lands under `chat/<conversation>/webhook-avatar-`
  /// before it will accept the URL.
  Future<ChatPresignResult> presignAvatar(
    String conversationId, {
    required String contentType,
    required int sizeBytes,
  }) async {
    final res = await _client.post(
      ApiConstants.personalWebhookAvatarPresign(conversationId),
      data: {'content_type': contentType, 'size_bytes': sizeBytes},
    );
    return ChatPresignResult.fromJson(unwrapApiData<Map<String, dynamic>>(res));
  }

  /// An empty [avatarUrl] clears the photo and deletes the stored object.
  Future<String> saveAvatar(String conversationId, String avatarUrl) async {
    final res = await _client.patch(
      ApiConstants.personalWebhookAvatar(conversationId),
      data: {'avatar_url': avatarUrl},
    );
    final data = unwrapApiData<Map<String, dynamic>>(res);
    return data['avatar_url'] as String? ?? '';
  }
}
