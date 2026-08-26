import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../fcm_log.dart';
import 'device_identity.dart';

/// Registers / deregisters FCM device tokens with the API.
class DeviceRepository {
  DeviceRepository(this._client);

  final ApiClient _client;

  /// Push shapes this build understands, recorded with the token.
  ///
  /// Diagnostics only now: the server shapes an encrypted DM push from the
  /// platform alone, because gating on this capability meant a phone with a
  /// stale token row (a reinstall gets a new FCM token, the old row lingers)
  /// received both shapes and showed every DM twice — once as the system-drawn
  /// "🔒 Encrypted message", once as this app's decrypted entry. Android now
  /// always gets the data-only shape and decrypts it here. The server picks
  /// that shape in code alone — no capability, no environment variable — so
  /// nothing outside the two Go senders can put a placeholder notification
  /// back beside this app's entry.
  static const pushCaps = <String>['e2ee_push'];

  Future<void> register(String fcmToken, {String platform = 'android'}) async {
    final url = '${ApiConstants.baseUrl}${ApiConstants.devices}';
    final deviceId = await DeviceIdentity.get();
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
          // Lets the server drop the rows this handset left behind under
          // earlier tokens, so one phone is never pushed to twice.
          'device_id': deviceId,
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
