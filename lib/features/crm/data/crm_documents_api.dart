import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import 'models/crm_models.dart';

class CrmDocumentsApi {
  const CrmDocumentsApi(this._client);
  final ApiClient _client;

  Future<List<CrmDocument>> list(String leadId) async {
    final res = await _client.get(ApiConstants.crmLeadDocuments(leadId));
    final raw = unwrapApiData<dynamic>(res);
    if (raw is! List) return const [];
    return [
      for (final e in raw)
        CrmDocument.fromJson(Map<String, dynamic>.from(e as Map)),
    ];
  }

  Future<CrmDocumentPresign> presign(
    String leadId, {
    required String contentType,
    required String fileName,
    required int sizeBytes,
  }) async {
    final res = await _client.post(
      ApiConstants.crmLeadDocumentsPresign(leadId),
      data: {
        'content_type': contentType,
        'file_name': fileName,
        'size_bytes': sizeBytes,
      },
    );
    return CrmDocumentPresign.fromJson(
      unwrapApiData<Map<String, dynamic>>(res),
    );
  }

  Future<CrmDocument> save(
    String leadId, {
    String? label,
    required String fileUrl,
    required String fileName,
    required String mimeType,
    required int sizeBytes,
  }) async {
    final res = await _client.post(
      ApiConstants.crmLeadDocuments(leadId),
      data: {
        if (label != null && label.isNotEmpty) 'label': label,
        'file_url': fileUrl,
        'file_name': fileName,
        'mime_type': mimeType,
        'size_bytes': sizeBytes,
      },
    );
    return CrmDocument.fromJson(unwrapApiData<Map<String, dynamic>>(res));
  }

  Future<void> discard(String fileUrl) async {
    await _client.post(
      ApiConstants.crmDocumentsDiscard,
      data: {'file_url': fileUrl},
    );
  }

  Future<void> delete(String docId) async {
    await _client.delete(ApiConstants.crmDocument(docId));
  }

  /// Presign → PUT to R2 → save row (web `uploadCRMDocument`).
  Future<CrmDocument> upload(
    String leadId, {
    required List<int> bytes,
    required String fileName,
    required String mimeType,
    String? label,
  }) async {
    final contentType =
        mimeType.isEmpty ? 'application/octet-stream' : mimeType;
    final presign = await this.presign(
      leadId,
      contentType: contentType,
      fileName: fileName,
      sizeBytes: bytes.length,
    );

    try {
      final dio = Dio();
      final put = await dio.put(
        presign.uploadUrl,
        data: bytes,
        options: Options(headers: {'Content-Type': contentType}),
      );
      if (put.statusCode == null ||
          put.statusCode! < 200 ||
          put.statusCode! >= 300) {
        throw Exception('Upload failed');
      }
    } catch (e) {
      try {
        await discard(presign.publicUrl);
      } catch (_) {}
      rethrow;
    }

    try {
      return await save(
        leadId,
        label: label,
        fileUrl: presign.publicUrl,
        fileName: fileName,
        mimeType: contentType,
        sizeBytes: bytes.length,
      );
    } catch (e) {
      try {
        await discard(presign.publicUrl);
      } catch (_) {}
      rethrow;
    }
  }
}
