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
    required String clientMessageId,
    required String body,
    String? encryptedBody,
    String? encryptionNonce,
    int? encryptionVersion,
    int? encryptionKeyVersion,
    String? parentId,
    String? quotedMessageId,
    List<ChatAttachmentInput> attachments = const [],
    List<String> mentionedUserIds = const [],
  }) async {
    final res = await _client.post(
      _endpoints.messages(conversationId),
      data: {
        'client_message_id': clientMessageId,
        'body': body,
        'encrypted_body': ?encryptedBody,
        'encryption_nonce': ?encryptionNonce,
        'encryption_version': ?encryptionVersion,
        'encryption_key_version': ?encryptionKeyVersion,
        'parent_id': ?parentId,
        'quoted_message_id': ?quotedMessageId,
        if (attachments.isNotEmpty)
          'attachments': attachments.map((a) => a.toJson()).toList(),
        if (mentionedUserIds.isNotEmpty) 'mentioned_user_ids': mentionedUserIds,
        'media_policy': ?_mediaPolicy(attachments),
      },
    );
    return ChatMessage.fromJson(unwrapApiData<Map<String, dynamic>>(res));
  }

  /// The privacy-mode sheet sets one choice for every attachment of a send;
  /// the server takes it once per message. Null when nothing is restricted.
  static Map<String, dynamic>? _mediaPolicy(List<ChatAttachmentInput> atts) {
    for (final a in atts) {
      if (!a.restricted) continue;
      return {'view_seconds': a.viewSeconds, 'allow_save': !a.noSave};
    }
    return null;
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

  /// The receiver opens a timed photo (privacy mode): starts its clock and
  /// returns the real URLs, attachment id -> URL. Every other read withholds
  /// them, so this is the only way to the bytes. Empty for the sender and once
  /// the photo expired.
  Future<Map<String, String>> markMediaViewed(String messageId) async {
    final res = await _client.post('${_endpoints.message(messageId)}/viewed');
    final data = unwrapApiData<Map<String, dynamic>>(res);
    final out = <String, String>{};
    for (final item in data['attachments'] as List<dynamic>? ?? const []) {
      if (item is! Map) continue;
      final id = item['id'] as String? ?? '';
      final url = item['file_url'] as String? ?? '';
      if (id.isNotEmpty && url.isNotEmpty) out[id] = url;
    }
    return out;
  }

  /// "Delete for me" — hidden for this account only.
  Future<void> hideMessage(String messageId) async {
    await _client.post('${_endpoints.message(messageId)}/hide');
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
