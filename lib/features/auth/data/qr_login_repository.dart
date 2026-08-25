import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';

/// Approves or rejects a desktop/web QR sign-in handshake scanned by this
/// phone. The scanned payload is `ababilx://desktop-login?t=<token>`; the
/// backend accepts either the full URL or the bare token.
class QrLoginRepository {
  QrLoginRepository(this._api);

  final ApiClient _api;

  static const String scanPrefix = 'ababilx://desktop-login';

  bool isLoginPayload(String raw) => raw.trim().startsWith(scanPrefix);

  /// What the phone is about to approve: which app asked, and from where.
  Future<QrLoginRequest> inspect(String payload) async {
    try {
      final res = await _api.post(
        ApiConstants.qrLoginInfo,
        data: {'token': payload.trim()},
      );
      final data = unwrapApiData<Map<String, dynamic>>(res);
      return QrLoginRequest(
        deviceName: (data['device_name'] ?? '').toString(),
        requestIp: (data['request_ip'] ?? '').toString(),
      );
    } on DioException catch (e) {
      if (_isExpired(e)) throw QrLoginExpired();
      rethrow;
    }
  }

  Future<void> approve(String payload) =>
      _send(ApiConstants.qrLoginApprove, payload);

  Future<void> deny(String payload) => _send(ApiConstants.qrLoginDeny, payload);

  Future<void> _send(String path, String payload) async {
    try {
      await _api.post(path, data: {'token': payload.trim()});
    } on DioException catch (e) {
      if (_isExpired(e)) throw QrLoginExpired();
      rethrow;
    }
  }

  bool _isExpired(DioException e) {
    final body = e.response?.data;
    final code = body is Map ? body['error']?.toString() : null;
    return code == 'qr_expired' || e.response?.statusCode == 410;
  }
}

/// Details of a pending handshake, shown before the user approves it.
class QrLoginRequest {
  const QrLoginRequest({required this.deviceName, required this.requestIp});

  final String deviceName;
  final String requestIp;
}

/// The handshake was already used, rejected, or timed out.
class QrLoginExpired implements Exception {}

final qrLoginRepositoryProvider = Provider<QrLoginRepository>(
  (ref) => QrLoginRepository(ref.watch(apiClientProvider)),
);
