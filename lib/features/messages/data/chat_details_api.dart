import '../../../core/network/api_client.dart';
import 'chat_endpoints.dart';
import 'models/chat_models.dart';

/// The three reads and one write behind the reference app's
/// conversation-details screen: shared media, groups in common, and reporting
/// the conversation.
class ChatDetailsApi {
  const ChatDetailsApi(this._client, this._endpoints);

  final ApiClient _client;
  final ChatEndpoints _endpoints;

  /// [kind] is `media` (pictures and video), `files` (everything else, voice
  /// notes included) or `all`.
  Future<ChatMediaPage> listMedia(
    String conversationId, {
    String kind = 'media',
    String? cursor,
    int limit = 30,
  }) async {
    final res = await _client.get(
      _endpoints.media(conversationId),
      queryParameters: {
        'kind': kind,
        'limit': limit,
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      },
    );
    return ChatMediaPage.fromJson(unwrapApiData<Map<String, dynamic>>(res));
  }

  Future<ChatGroupsInCommon> groupsInCommon(String userId) async {
    final res = await _client.get(_endpoints.groupsInCommon(userId));
    return ChatGroupsInCommon.fromJson(
      unwrapApiData<Map<String, dynamic>>(res),
    );
  }

  /// Files a report. [block] asks for the reporter's own recourse in the same
  /// tap; the two are separate on the server and either can succeed alone.
  Future<void> reportConversation(
    String conversationId, {
    String reason = 'spam',
    bool block = false,
  }) async {
    await _client.post(
      _endpoints.report(conversationId),
      data: {'reason': reason, 'block': block},
    );
  }
}
