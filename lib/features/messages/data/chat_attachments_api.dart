import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import 'models/chat_models.dart';

class ChatAttachmentsApi {
  const ChatAttachmentsApi(this._client);

  final ApiClient _client;

  Future<ChatPresignResult> presignAttachment(
    String conversationId, {
    required String contentType,
    required String fileName,
    required int sizeBytes,
  }) async {
    final res = await _client.post(
      ApiConstants.chatConversationPresign(conversationId),
      data: {
        'content_type': contentType,
        'file_name': fileName,
        'size_bytes': sizeBytes,
      },
    );
    return ChatPresignResult.fromJson(unwrapApiData<Map<String, dynamic>>(res));
  }

  Future<void> discardUpload(String conversationId, String fileUrl) async {
    await _client.post(
      ApiConstants.chatConversationDiscard(conversationId),
      data: {'file_url': fileUrl},
    );
  }
}
