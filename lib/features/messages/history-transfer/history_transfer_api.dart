import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import 'history_transfer_envelope_codec.dart';
import 'history_window.dart';

/// The phone's half of `/api/messaging/history-transfers/*`.
///
/// The phone is always the SOURCE: it inspects a scanned code, approves it,
/// uploads sealed chunks and commits the manifest. Listing and acknowledging
/// chunks belong to the destination and are deliberately absent here.
class HistoryTransferApi {
  const HistoryTransferApi(this._client);

  final ApiClient _client;

  /// What the destination device says it is, before anything is approved.
  /// The verification code is NOT taken from this: both screens derive it from
  /// the ephemeral key — the phone's copy read off the camera — so a code the
  /// server chose could never be compared against anything.
  Future<HistoryTransferRequest> inspect(String token) async {
    final res = await _client.post(
      ApiConstants.historyTransferInfo,
      data: {'token': token},
    );
    return HistoryTransferRequest.fromJson(
      unwrapApiData<Map<String, dynamic>>(res),
    );
  }

  /// One-scan sign-in: the transfer the new device opened right after the
  /// sign-in this phone approved, found by that sign-in token. Throws a 404
  /// `history_transfer_not_ready` until the device has opened it.
  Future<HistoryTransferRequest> inspectByLogin(String loginToken) async {
    final res = await _client.post(
      ApiConstants.historyTransferInfo,
      data: {'login_token': loginToken},
    );
    return HistoryTransferRequest.fromJson(
      unwrapApiData<Map<String, dynamic>>(res),
    );
  }

  /// Approves and opens the 24-hour relay window. The public key is echoed so
  /// the server can refuse a token whose key it does not recognise — a
  /// substituted pairing fails here rather than being sealed to a stranger.
  ///
  /// v2 passes [destinationKeyParam], the scanned `k` exactly as the camera
  /// read it: the server compares it to what the destination registered as a
  /// string, and re-encoding a decoded JWK is one key-order change away from
  /// a mismatch that reads as a substituted key.
  Future<String> approve({
    required String token,
    required String deviceName,
    required Map<String, dynamic> envelope,
    required Map<String, dynamic> destinationJwk,
    String? destinationKeyParam,
    String? loginToken,
    bool live = false,
  }) async {
    final res = await _client.post(
      ApiConstants.historyTransferApprove,
      data: {
        'token': token,
        'login_token': ?loginToken,
        // Live history link (server 0175): no relay upload, the phone answers
        // the new device over WebRTC.
        if (live) 'live': true,
        'device_name': deviceName,
        'transfer_envelope': _encodeEnvelope(envelope),
        'destination_public_key':
            destinationKeyParam ?? _jwkParam(destinationJwk),
      },
    );
    return unwrapApiData<Map<String, dynamic>>(res)['id'] as String;
  }

  Future<void> deny(String token) =>
      _client.post(ApiConstants.historyTransferDeny, data: {'token': token});

  Future<Map<String, dynamic>> status(String id) async {
    final res = await _client.get('${ApiConstants.historyTransfers}/$id');
    return unwrapApiData<Map<String, dynamic>>(res);
  }

  Future<Map<String, dynamic>?> active() async {
    final res = await _client.get(ApiConstants.historyTransferActive);
    final data = unwrapApiData<Map<String, dynamic>>(res);
    return data['active'] == true ? data : null;
  }

  /// Reserves a chunk and signs its upload.
  ///
  /// `uploaded == true` means the server already holds this index and it is
  /// frozen — a resumed export must skip it rather than re-uploading, because
  /// the destination may have read it already.
  Future<HistoryTransferSlot> reserveChunk({
    required String id,
    required int index,
    required String kind,
    required int sizeBytes,
  }) async {
    final res = await _client.post(
      '${ApiConstants.historyTransfers}/$id/chunks',
      data: {'index': index, 'kind': kind, 'size_bytes': sizeBytes},
    );
    final data = unwrapApiData<Map<String, dynamic>>(res);
    return HistoryTransferSlot(
      uploadUrl: data['upload_url'] as String? ?? '',
      alreadyUploaded: data['uploaded'] == true,
    );
  }

  Future<void> confirmChunk({
    required String id,
    required int index,
    required String checksum,
  }) => _client.post(
    '${ApiConstants.historyTransfers}/$id/chunks/$index/uploaded',
    data: {'checksum': checksum},
  );

  Future<void> commitManifest({
    required String id,
    required String ciphertext,
    required int chunks,
  }) => _client.post(
    '${ApiConstants.historyTransfers}/$id/manifest',
    data: {'ciphertext': ciphertext, 'chunks': chunks},
  );

  Future<void> cancel(String id) =>
      _client.post('${ApiConstants.historyTransfers}/$id/cancel');

  /// Uploads one sealed chunk straight to the relay bucket.
  ///
  /// A bare Dio, not the API client: the presigned URL carries its own
  /// signature and an Authorization header would make the store reject it. The
  /// length is sent exactly as reserved — the server signs `content-length`, so
  /// anything else is refused by the signature itself.
  Future<void> putChunk(String uploadUrl, List<int> bytes) => Dio().put(
    uploadUrl,
    data: Stream.value(bytes),
    options: Options(
      headers: {
        'Content-Type': 'application/octet-stream',
        'Content-Length': bytes.length,
      },
    ),
  );

  String _encodeEnvelope(Map<String, dynamic> envelope) =>
      HistoryTransferEnvelopeCodec.encode(envelope);

  String _jwkParam(Map<String, dynamic> jwk) =>
      HistoryTransferEnvelopeCodec.encode(jwk);
}

/// The destination device, as the server describes it.
class HistoryTransferRequest {
  const HistoryTransferRequest({
    required this.id,
    required this.deviceName,
    required this.client,
    required this.version,
    this.historyDays = defaultHistoryWindowDays,
  });

  final String id;
  final String deviceName;
  final String client;
  final int version;

  /// `history_days`: how far back this phone sends (server 0174).
  final int historyDays;

  factory HistoryTransferRequest.fromJson(Map<String, dynamic> json) =>
      HistoryTransferRequest(
        id: json['id'] as String? ?? '',
        deviceName: json['destination_device_name'] as String? ?? '',
        client: json['destination_client'] as String? ?? '',
        version: (json['transfer_version'] as num?)?.toInt() ?? 1,
        historyDays: historyWindowDays(json['history_days']),
      );
}

class HistoryTransferSlot {
  const HistoryTransferSlot({
    required this.uploadUrl,
    required this.alreadyUploaded,
  });

  final String uploadUrl;
  final bool alreadyUploaded;
}
