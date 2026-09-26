import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../messages/data/chat_endpoints.dart';
import '../messages/data/models/chat_message.dart';
import 'private_op.dart';

/// What one phone still owes custody for (server 0160).
class PrivatePending {
  const PrivatePending({
    this.messages = const [],
    this.ops = const [],
    this.hasMore = false,
  });

  final List<ChatMessage> messages;
  final List<PrivateOp> ops;
  final bool hasMore;

  bool get isEmpty => messages.isEmpty && ops.isEmpty;
}

/// The private-chat routes: the switch, a phone's custody pull and
/// acknowledgement, and ops on private messages.
class PrivateChatApi {
  const PrivateChatApi(this._client);

  final ApiClient _client;

  /// Returns the stored state: `(enabled, by)`.
  Future<(bool, String)> setEnabled(String conversationId, bool enabled) async {
    final res = await _client.put(
      const ChatEndpoints().action(conversationId, 'private-chat'),
      data: {'enabled': enabled},
    );
    final data = unwrapApiData<Map<String, dynamic>>(res);
    return (
      data['private_chat'] as bool? ?? enabled,
      data['private_chat_by'] as String? ?? '',
    );
  }

  Future<PrivatePending> pending(String deviceId) async {
    final res = await _client.get(
      ApiConstants.privateChatPending,
      queryParameters: {'device_id': deviceId},
    );
    final data = unwrapApiData<Map<String, dynamic>>(res);
    return PrivatePending(
      messages: (data['messages'] as List<dynamic>? ?? const [])
          .map((e) => ChatMessage.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      ops: (data['ops'] as List<dynamic>? ?? const [])
          .map((e) => PrivateOp.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      hasMore: data['has_more'] == true,
    );
  }

  /// Tells the server these are on this phone's disk, media included — the
  /// last phone to say so releases them from the server.
  Future<void> custody(String deviceId, List<String> ids) async {
    for (var i = 0; i < ids.length; i += 200) {
      final end = i + 200 < ids.length ? i + 200 : ids.length;
      await _client.post(
        ApiConstants.privateChatCustody,
        data: {'device_id': deviceId, 'ids': ids.sublist(i, end)},
      );
    }
  }

  Future<PrivateOp> postOp(
    String conversationId,
    Map<String, dynamic> body,
  ) async {
    final res = await _client.post(
      const ChatEndpoints().action(conversationId, 'private-ops'),
      data: body,
    );
    return PrivateOp.fromJson(unwrapApiData<Map<String, dynamic>>(res));
  }
}

final privateChatApiProvider = Provider<PrivateChatApi>(
  (ref) => PrivateChatApi(ref.watch(apiClientProvider)),
);
