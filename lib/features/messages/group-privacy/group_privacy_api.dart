import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../data/models/chat_models.dart';

/// `PUT /api/chat/conversations/:id/group-privacy` — admins only (server
/// 0154). Answers with the updated conversation row.
Future<ChatConversation> putGroupPrivacy(
  ApiClient client,
  String conversationId, {
  required bool enabled,
}) async {
  final res = await client.put(
    ApiConstants.independentChatConversationAction(
      conversationId,
      'group-privacy',
    ),
    data: {'enabled': enabled},
  );
  return ChatConversation.fromJson(unwrapApiData<Map<String, dynamic>>(res));
}
