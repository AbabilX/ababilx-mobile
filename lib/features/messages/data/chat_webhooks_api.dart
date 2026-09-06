import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import 'models/chat_models.dart';

/// Webhook feeds: a workspace conversation nobody can post into, filled only
/// by inbound HTTP.
///
/// These paths are workspace-only on purpose and never routed through
/// [ChatEndpoints] — the server's scope constraint refuses a personal-scope
/// webhook conversation, so an `/api/chat/*` twin would be a 404 by design.
class ChatWebhooksApi {
  const ChatWebhooksApi(this._client);

  final ApiClient _client;

  /// Creates the feed and its endpoint in one call. The response is the only
  /// time the secret URL exists.
  Future<({ChatConversation conversation, ChatWebhookCreated created})>
  createWebhookChannel({
    required String name,
    String? slug,
    bool isPrivate = false,
  }) async {
    final res = await _client.post(
      ApiConstants.chatWebhookChannels,
      data: {'name': name, 'slug': ?slug, 'is_private': isPrivate},
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
      ApiConstants.chatWebhookRegenerate(conversationId),
    );
    return ChatWebhookCreated.fromJson(
      unwrapApiData<Map<String, dynamic>>(res),
    );
  }

  /// The feed's own presign, not the conversation attachment one: the server
  /// checks the object lands under `teams/<team>/chat-webhooks/<hook>/avatar-`
  /// before it will accept the URL.
  Future<ChatPresignResult> presignAvatar(
    String conversationId, {
    required String contentType,
    required int sizeBytes,
  }) async {
    final res = await _client.post(
      ApiConstants.chatWebhookAvatarPresign(conversationId),
      data: {'content_type': contentType, 'size_bytes': sizeBytes},
    );
    return ChatPresignResult.fromJson(unwrapApiData<Map<String, dynamic>>(res));
  }

  /// An empty [avatarUrl] clears the photo and deletes the stored object.
  Future<String> saveAvatar(String conversationId, String avatarUrl) async {
    final res = await _client.patch(
      ApiConstants.chatWebhookAvatar(conversationId),
      data: {'avatar_url': avatarUrl},
    );
    final data = unwrapApiData<Map<String, dynamic>>(res);
    return data['avatar_url'] as String? ?? '';
  }
}
