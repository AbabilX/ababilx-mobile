import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import 'models/chat_models.dart';

/// Webhook feeds: a conversation nobody can post into, filled only by inbound
/// HTTP.
///
/// A feed exists in either scope. A **workspace** feed belongs to a team and
/// every active member reads it; a **personal** feed belongs to one account,
/// needs no workspace at all, and starts with its creator alone (migration
/// 0128). The two are the same conversation type under two path prefixes.
///
/// Every method here takes [personal] explicitly rather than reading the app's
/// independent-chat flag: an account can hold both kinds at once, so the path
/// has to follow the conversation being acted on, not the mode the app happens
/// to be in.
class ChatWebhooksApi {
  const ChatWebhooksApi(this._client);

  final ApiClient _client;

  /// Creates the feed and its endpoint in one call. The response is the only
  /// time the secret URL exists.
  ///
  /// A personal feed takes a name and nothing else: it has no slug, and with
  /// no team there is nobody a "public" feed could be open to, so the server
  /// ignores both fields rather than pretending they mean something.
  Future<({ChatConversation conversation, ChatWebhookCreated created})>
  createWebhookChannel({
    required String name,
    required bool personal,
    String? slug,
    bool isPrivate = false,
  }) async {
    final res = await _client.post(
      personal
          ? ApiConstants.personalWebhookChannels
          : ApiConstants.chatWebhookChannels,
      data: personal
          ? {'name': name}
          : {'name': name, 'slug': ?slug, 'is_private': isPrivate},
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
  Future<ChatWebhookCreated> regenerate(
    String conversationId, {
    required bool personal,
  }) async {
    final res = await _client.post(
      personal
          ? ApiConstants.personalWebhookRegenerate(conversationId)
          : ApiConstants.chatWebhookRegenerate(conversationId),
    );
    return ChatWebhookCreated.fromJson(
      unwrapApiData<Map<String, dynamic>>(res),
    );
  }

  /// The feed's own presign, not the conversation attachment one: the server
  /// checks the object lands under the feed's own prefix —
  /// `teams/<team>/chat-webhooks/<hook>/avatar-` for a workspace feed,
  /// `chat/<conversation>/webhook-avatar-` for a personal one — before it will
  /// accept the URL.
  Future<ChatPresignResult> presignAvatar(
    String conversationId, {
    required String contentType,
    required int sizeBytes,
    required bool personal,
  }) async {
    final res = await _client.post(
      personal
          ? ApiConstants.personalWebhookAvatarPresign(conversationId)
          : ApiConstants.chatWebhookAvatarPresign(conversationId),
      data: {'content_type': contentType, 'size_bytes': sizeBytes},
    );
    return ChatPresignResult.fromJson(unwrapApiData<Map<String, dynamic>>(res));
  }

  /// An empty [avatarUrl] clears the photo and deletes the stored object.
  Future<String> saveAvatar(
    String conversationId,
    String avatarUrl, {
    required bool personal,
  }) async {
    final res = await _client.patch(
      personal
          ? ApiConstants.personalWebhookAvatar(conversationId)
          : ApiConstants.chatWebhookAvatar(conversationId),
      data: {'avatar_url': avatarUrl},
    );
    final data = unwrapApiData<Map<String, dynamic>>(res);
    return data['avatar_url'] as String? ?? '';
  }
}
