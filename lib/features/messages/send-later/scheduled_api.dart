import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import 'scheduled_message.dart';

/// Send later (server 0171). Every route is under `/api/chat`.
const _root = '${ApiConstants.independentChatRoot}/scheduled';

String _inConversation(String conversationId) =>
    ApiConstants.independentChatConversationAction(conversationId, 'scheduled');

List<ScheduledMessage> _rows(dynamic response) {
  final data = unwrapApiData<Map<String, dynamic>>(response);
  return [
    for (final row in data['scheduled'] as List? ?? const [])
      if (row is Map) ScheduledMessage.fromJson(Map<String, dynamic>.from(row)),
  ];
}

/// This account's scheduled messages in one conversation, soonest first.
Future<List<ScheduledMessage>> listScheduled(
  ApiClient client,
  String conversationId,
) async => _rows(await client.get(_inConversation(conversationId)));

/// Every scheduled message of this account's.
Future<List<ScheduledMessage>> listAllScheduled(ApiClient client) async =>
    _rows(await client.get(_root));

/// Stores [request] — a whole send body — to be sent at [sendAt].
Future<ScheduledMessage> createScheduled(
  ApiClient client,
  String conversationId, {
  required DateTime sendAt,
  required Map<String, dynamic> request,
}) async {
  final res = await client.post(
    _inConversation(conversationId),
    data: {'send_at': sendAt.toUtc().toIso8601String(), 'message': request},
  );
  return ScheduledMessage.fromJson(unwrapApiData<Map<String, dynamic>>(res));
}

/// Moves one to another time, and/or replaces its request with the same
/// message sealed again.
Future<ScheduledMessage> patchScheduled(
  ApiClient client,
  String id, {
  DateTime? sendAt,
  Map<String, dynamic>? request,
}) async {
  final res = await client.patch(
    '$_root/$id',
    data: {'send_at': ?sendAt?.toUtc().toIso8601String(), 'message': ?request},
  );
  return ScheduledMessage.fromJson(unwrapApiData<Map<String, dynamic>>(res));
}

/// Sends one at once. Throws with the send path's own refusal when it does
/// not go out.
Future<void> sendScheduledNow(ApiClient client, String id) =>
    client.post('$_root/$id/send');

Future<void> deleteScheduled(ApiClient client, String id) =>
    client.delete('$_root/$id');
