import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';

/// Contact avatar upload — web `crm-contact-media.ts`.
class CrmContactMediaApi {
  const CrmContactMediaApi(this._client);
  final ApiClient _client;

  Future<({String uploadUrl, String publicUrl})> presign({
    required String contentType,
    required int sizeBytes,
  }) async {
    final res = await _client.post(
      ApiConstants.crmContactImagesPresign,
      data: {
        'content_type': contentType,
        'size_bytes': sizeBytes,
      },
    );
    final data = unwrapApiData<Map<String, dynamic>>(res);
    return (
      uploadUrl: data['upload_url'] as String? ?? '',
      publicUrl: data['public_url'] as String? ?? '',
    );
  }

  Future<void> discard(String imageUrl) async {
    await _client.post(
      ApiConstants.crmContactImagesDiscard,
      data: {'image_url': imageUrl},
    );
  }

  /// Presign → PUT R2 → return public URL (attach via contact create/update).
  Future<String> upload({
    required List<int> bytes,
    required String contentType,
  }) async {
    final draft = await presign(
      contentType: contentType,
      sizeBytes: bytes.length,
    );
    try {
      final dio = Dio();
      final put = await dio.put(
        draft.uploadUrl,
        data: bytes,
        options: Options(headers: {'Content-Type': contentType}),
      );
      if (put.statusCode == null ||
          put.statusCode! < 200 ||
          put.statusCode! >= 300) {
        throw Exception('Image upload failed');
      }
      return draft.publicUrl;
    } catch (e) {
      try {
        await discard(draft.publicUrl);
      } catch (_) {}
      rethrow;
    }
  }
}
