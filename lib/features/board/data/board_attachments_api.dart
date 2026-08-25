import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import 'models/board_models.dart';

class BoardAttachmentsApi {
  const BoardAttachmentsApi(this._client);
  final ApiClient _client;

  Future<KanbanPresignResult> presign(
    String taskId, {
    required String contentType,
    required String fileName,
    required int sizeBytes,
  }) async {
    final res = await _client.post(
      ApiConstants.kanbanTaskAttachmentsPresign(taskId),
      data: {
        'content_type': contentType,
        'file_name': fileName,
        'size_bytes': sizeBytes,
      },
    );
    return KanbanPresignResult.fromJson(
      unwrapApiData<Map<String, dynamic>>(res),
    );
  }

  Future<void> discard(String taskId, String fileUrl) async {
    await _client.post(
      ApiConstants.kanbanTaskAttachmentsDiscard(taskId),
      data: {'file_url': fileUrl},
    );
  }

  Future<void> uploadBytes(
    KanbanPresignResult presign,
    Uint8List bytes,
    String contentType,
  ) async {
    await Dio().put(
      presign.uploadUrl,
      data: bytes,
      options: Options(
        headers: {'Content-Type': contentType, 'Content-Length': bytes.length},
      ),
    );
  }
}
