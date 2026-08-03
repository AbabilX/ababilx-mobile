import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import 'models/wall_models.dart';

class WallAttachmentsApi {
  const WallAttachmentsApi(this._client);
  final ApiClient _client;

  Future<WallPresignResult> presign({
    required String contentType,
    required String fileName,
    required int sizeBytes,
  }) async {
    final res = await _client.post(
      ApiConstants.wallAttachmentsPresign,
      data: {
        'content_type': contentType,
        'file_name': fileName,
        'size_bytes': sizeBytes,
      },
    );
    return WallPresignResult.fromJson(unwrapApiData<Map<String, dynamic>>(res));
  }

  Future<void> discard(String fileUrl) async {
    await _client.post(
      ApiConstants.wallAttachmentsDiscard,
      data: {'file_url': fileUrl},
    );
  }

  Future<void> uploadBytes(
    WallPresignResult presign,
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

class WallMetaApi {
  const WallMetaApi(this._client);
  final ApiClient _client;

  Future<List<WallCategory>> listCategories() async {
    final res = await _client.get(ApiConstants.wallCategories);
    final data = unwrapApiData<List<dynamic>>(res);
    return data
        .map((e) => WallCategory.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<WallStats> stats() async {
    final res = await _client.get(ApiConstants.wallStats);
    return WallStats.fromJson(unwrapApiData<Map<String, dynamic>>(res));
  }

  Future<WallSearchResponse> search(String q, {int limit = 10}) async {
    final res = await _client.get(
      ApiConstants.wallSearch,
      queryParameters: {'q': q, 'limit': limit},
    );
    return WallSearchResponse.fromJson(
      unwrapApiData<Map<String, dynamic>>(res),
    );
  }

  Future<int> forward({
    required String postId,
    List<String>? conversationIds,
    List<String>? userIds,
    String? caption,
  }) async {
    final res = await _client.post(
      ApiConstants.wallForward,
      data: {
        'post_id': postId,
        'conversation_ids': ?conversationIds,
        'user_ids': ?userIds,
        if (caption != null && caption.isNotEmpty) 'caption': caption,
      },
    );
    final data = unwrapApiData<Map<String, dynamic>>(res);
    return data['forwarded_to'] as int? ?? 0;
  }
}
