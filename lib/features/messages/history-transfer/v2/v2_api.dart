import 'package:dio/dio.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';

/// The phone's half of the v2 routes (`/api/messaging/history-transfers/:id/v2/*`).
/// The phone is always the source: it never lists or acknowledges chunks.
class HistoryTransferV2Api {
  const HistoryTransferV2Api(this._client, {this.relay});

  final ApiClient _client;

  /// Injected by tests; the app uses a fresh bare Dio per upload.
  final Dio? relay;

  String _job(String id) => '${ApiConstants.historyTransfers}/$id/v2';

  Future<Map<String, dynamic>> capabilities() async => unwrapApiData<Map<String, dynamic>>(
    await _client.get('${ApiConstants.historyTransfers}/capabilities'),
  );

  /// Job state: status, inventories, seal, every batch with its progress.
  Future<Map<String, dynamic>> job(String id) async =>
      unwrapApiData<Map<String, dynamic>>(await _client.get(_job(id)));

  Future<void> putInventory(String id, String ciphertext) =>
      _client.put('${_job(id)}/inventory', data: {'ciphertext': ciphertext});

  Future<void> createBatch(String id, int batch, String kind, bool isFinal) => _client.post(
    '${_job(id)}/batches',
    data: {'batch': batch, 'kind': kind, 'final': isFinal},
  );

  /// Reserves a chunk. `uploaded` means the server already holds it — frozen,
  /// and a resumed run must skip it. A full relay answers
  /// [HistoryTransferRelayBusy], which is a wait, never a failure.
  Future<({String url, bool uploaded})> reserve(String id, int batch, int index, int size) async {
    try {
      final data = unwrapApiData<Map<String, dynamic>>(
        await _client.post(
          '${_job(id)}/batches/$batch/chunks',
          data: {'index': index, 'size_bytes': size},
        ),
      );
      return (url: data['upload_url'] as String? ?? '', uploaded: data['uploaded'] == true);
    } on DioException catch (error) {
      final body = error.response?.data;
      if (body is Map && body['error'] == 'history_transfer_relay_busy') {
        final data = body['data'];
        final seconds = data is Map ? (data['retry_after_seconds'] as num?)?.toInt() : null;
        throw HistoryTransferRelayBusy(Duration(seconds: seconds ?? 30));
      }
      rethrow;
    }
  }

  Future<void> confirm(String id, int batch, int index, String checksum) => _client.post(
    '${_job(id)}/batches/$batch/chunks/$index/uploaded',
    data: {'checksum': checksum},
  );

  Future<void> putPage(String id, int batch, int page, String ciphertext) =>
      _client.put('${_job(id)}/batches/$batch/pages/$page', data: {'ciphertext': ciphertext});

  Future<void> finalize(String id, int batch, int chunks, int pages) => _client.post(
    '${_job(id)}/batches/$batch/finalize',
    data: {'chunk_count': chunks, 'page_count': pages},
  );

  Future<void> putSeal(String id, int lastBatch, String ciphertext) =>
      _client.put('${_job(id)}/seal', data: {'ciphertext': ciphertext, 'last_batch': lastBatch});

  /// Straight to the relay bucket with a bare Dio: the signature is in the
  /// URL, and an Authorization header would make the store refuse it. The
  /// length is exactly what was reserved — it is signed.
  Future<void> put(String url, List<int> bytes) => (relay ?? Dio()).put(
    url,
    data: Stream.value(bytes),
    options: Options(
      headers: {'Content-Type': 'application/octet-stream', 'Content-Length': bytes.length},
    ),
  );
}

class HistoryTransferRelayBusy implements Exception {
  const HistoryTransferRelayBusy(this.retryAfter);

  final Duration retryAfter;
}

/// The server's error code off a failed call, or ''.
String historyTransferErrorCode(Object error) {
  if (error is! DioException) return '';
  final body = error.response?.data;
  return body is Map ? (body['error']?.toString() ?? '') : '';
}
