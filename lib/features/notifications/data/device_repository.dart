import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../fcm_log.dart';

/// Registers / deregisters FCM device tokens with the API.
class DeviceRepository {
  DeviceRepository(this._client);

  final ApiClient _client;

  /// Push shapes this build understands. `e2ee_push` tells the server this app
  /// has the background handler that decrypts a data-only encrypted DM — a
  /// build without it must keep receiving normal tray notifications, or the
  /// message would arrive with nothing shown at all.
  ///
  /// Left empty for now: a build that declared this stopped receiving any
  /// notification at all for encrypted DMs on-device, cause not yet found.
  /// Re-enable only after that is confirmed reliable via a device test.
  static const pushCaps = <String>[];

  Future<void> register(String fcmToken, {String platform = 'android'}) async {
    final url = '${ApiConstants.baseUrl}${ApiConstants.devices}';
    fcmLog(
      'api.register.start',
      'POST $url platform=$platform token=${fcmTokenPreview(fcmToken)}',
    );
    try {
      final res = await _client.post(
        ApiConstants.devices,
        data: {
          'fcm_token': fcmToken,
          'platform': platform,
          'push_caps': pushCaps,
        },
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
