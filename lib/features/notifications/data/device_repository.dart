import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../fcm_log.dart';

/// Registers / deregisters FCM device tokens with the API.
class DeviceRepository {
  DeviceRepository(this._client);

  final ApiClient _client;

  Future<void> register(String fcmToken, {String platform = 'android'}) async {
    final url = '${ApiConstants.baseUrl}${ApiConstants.devices}';
    fcmLog(
      'api.register.start',
      'POST $url platform=$platform token=${fcmTokenPreview(fcmToken)}',
    );
    try {
      final res = await _client.post(
        ApiConstants.devices,
        data: {'fcm_token': fcmToken, 'platform': platform},
      );
      fcmLog('api.register.ok', 'status=${res.statusCode} body=${res.data}');
    } on DioException catch (e) {
      fcmLog(
        'api.register.fail',
        'status=${e.response?.statusCode} message=${e.message} body=${e.response?.data}',
      );
      rethrow;
    } catch (e) {
      fcmLog('api.register.fail', e);
      rethrow;
    }
  }

  Future<void> deregister(String fcmToken) async {
    fcmLog('api.deregister.start', 'token=${fcmTokenPreview(fcmToken)}');
    try {
      final res = await _client.delete(
        ApiConstants.devices,
        data: {'fcm_token': fcmToken},
      );
      fcmLog('api.deregister.ok', 'status=${res.statusCode}');
    } on DioException catch (e) {
      fcmLog(
        'api.deregister.fail',
        'status=${e.response?.statusCode} message=${e.message} body=${e.response?.data}',
      );
      rethrow;
    } catch (e) {
      fcmLog('api.deregister.fail', e);
      rethrow;
    }
  }
}
