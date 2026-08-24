import '../../../core/network/api_client.dart';
import 'models/chat_models.dart';
import 'chat_endpoints.dart';

class ChatAttachmentsApi {
  const ChatAttachmentsApi(this._client, this._endpoints);

  final ApiClient _client;
  final ChatEndpoints _endpoints;

  Future<ChatPresignResult> presignAttachment(
    String conversationId, {
    required String contentType,
    required String fileName,
    required int sizeBytes,
  }) async {
    final res = await _client.post(
      _endpoints.action(conversationId, 'attachments/presign'),
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
      _endpoints.action(conversationId, 'attachments/discard'),
      data: {'file_url': fileUrl},
    );
  }
}
