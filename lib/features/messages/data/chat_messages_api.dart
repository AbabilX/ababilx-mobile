import '../../../core/network/api_client.dart';
import 'models/chat_models.dart';
import 'chat_endpoints.dart';
import 'chat_send_body.dart';
import 'request_single_flight.dart';

class ChatMessagesApi {
  ChatMessagesApi(this._client, this._endpoints);

  final ApiClient _client;
  final ChatEndpoints _endpoints;
  final RequestSingleFlight<ChatMessagesPage> _pageRequests =
      RequestSingleFlight<ChatMessagesPage>();

  /// The caller's own pins in this chat, newest first, each carrying the
  /// message as the timeline serves it (still sealed when encrypted).
  Future<List<ChatPinnedMessage>> pinnedMessages(String conversationId) async {
    final response = await _client.get(
      _endpoints.pinnedMessages(conversationId),
    );
    final data = unwrapApiData<Map<String, dynamic>>(response);
    return [
      for (final pin in data['pins'] as List? ?? const [])
        ChatPinnedMessage.fromJson(pin as Map<String, dynamic>),
    ];
  }

  Future<void> setMessagePinned(
    String conversationId,
    String messageId, {
    required bool pinned,
  }) async {
    final path = _endpoints.pinnedMessage(conversationId, messageId);
    pinned ? await _client.put(path) : await _client.delete(path);
  }

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
    String? taskPriority,
  }) async {
    final res = await _client.post(
      _endpoints.messages(conversationId),
      data: chatSendBody(
        clientMessageId: clientMessageId,
        body: body,
        encryptedBody: encryptedBody,
        encryptionNonce: encryptionNonce,
        encryptionVersion: encryptionVersion,
        encryptionKeyVersion: encryptionKeyVersion,
        parentId: parentId,
        quotedMessageId: quotedMessageId,
        attachments: attachments,
        mentionedUserIds: mentionedUserIds,
        taskPriority: taskPriority,
      ),
    );
    return ChatMessage.fromJson(unwrapApiData<Map<String, dynamic>>(res));
  }

  /// Moves a task card's priority and/or status; answers the message as the
  /// server now holds it (still sealed when encrypted).
  Future<ChatMessage> updateTask(
    String messageId, {
    String? priority,
    String? status,
  }) async {
    final res = await _client.put(
      _endpoints.messageTask(messageId),
      data: {'priority': ?priority, 'status': ?status},
    );
    return ChatMessage.fromJson(unwrapApiData<Map<String, dynamic>>(res));
  }

  /// One page of the conversation's task cards, newest first. [state] is
  /// `open` or `closed`; [cursor] is the page before's `nextCursor`, which is
  /// null on the last page.
  Future<({List<ChatMessage> tasks, String? nextCursor})> listTasks(
    String conversationId, {
    String? state,
    String? cursor,
    int limit = 50,
  }) async {
    final res = await _client.get(
      _endpoints.tasks(conversationId),
      queryParameters: {'limit': limit, 'state': ?state, 'cursor': ?cursor},
    );
    final data = unwrapApiData<Map<String, dynamic>>(res);
    final next = data['next_cursor'];
    return (
      tasks: [
        for (final item in data['tasks'] as List? ?? const [])
          ChatMessage.fromJson(item as Map<String, dynamic>),
      ],
      nextCursor: next is String && next.isNotEmpty ? next : null,
    );
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
  /// returns the real URLs — and, for an encrypted photo, its sealed key — by
  /// attachment id. Every other read withholds them, so this is the only way
  /// to the bytes. Empty for the sender and once the photo expired.
  Future<Map<String, TimedMediaGrant>> markMediaViewed(String messageId) async {
    final res = await _client.post('${_endpoints.message(messageId)}/viewed');
    final data = unwrapApiData<Map<String, dynamic>>(res);
    final out = <String, TimedMediaGrant>{};
    for (final item in data['attachments'] as List<dynamic>? ?? const []) {
      if (item is! Map) continue;
      final id = item['id'] as String? ?? '';
      final grant = TimedMediaGrant.fromJson(Map<String, dynamic>.from(item));
      if (id.isNotEmpty && grant.url.isNotEmpty) out[id] = grant;
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
