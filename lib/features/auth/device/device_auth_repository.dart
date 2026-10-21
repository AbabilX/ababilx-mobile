import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../data/app_key.dart';
import '../data/auth_session.dart';
import 'device_account_key.dart';

/// A refusal the server explained: [code] to branch on, [message] to show.
class DeviceAuthException implements Exception {
  const DeviceAuthException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => message;
}

/// challenge -> sign -> register|login against `/auth/device/*`. Returns the
/// raw sign-in body (the same shape Google sign-in answers with). [dio] may
/// be a bare client: nothing here needs a session.
Future<Map<String, dynamic>> deviceSignIn(
  Dio dio,
  DeviceAccountKey key,
  String purpose,
) async {
  final options = Options(headers: {'X-APP-KEY': ababilxAppKey});
  try {
    final challenge = await dio.post<Map<String, dynamic>>(
      ApiConstants.deviceChallenge,
      data: {'purpose': purpose},
      options: options,
    );
    final data = challenge.data?['data'];
    if (data is! Map) throw const FormatException('No challenge');
    final nonce = DeviceAccountKey.decodeBytes(data['nonce'].toString());
    final signature = await key.sign(purpose, nonce);
    final response = await dio.post<Map<String, dynamic>>(
      purpose == 'register'
          ? ApiConstants.deviceRegister
          : ApiConstants.deviceLogin,
      data: {
        'challenge_id': data['challenge_id'],
        'public_key': key.encodedPublicKey,
        'signature': DeviceAccountKey.encodeBytes(signature),
      },
      options: options,
    );
    return response.data ?? const {};
  } on DioException catch (error) {
    final body = error.response?.data;
    if (body is Map && body['code'] is String) {
      throw DeviceAuthException(
        body['code'] as String,
        (body['message'] ?? body['error'] ?? '').toString(),
      );
    }
    rethrow;
  }
}

class DeviceAuthRepository {
  DeviceAuthRepository(this._client);

  final ApiClient _client;

  /// Creates a brand-new account owned by [key]. Every call is a new account.
  Future<PreparedAuthSession> register(DeviceAccountKey key) async {
    final body = await deviceSignIn(_client.dio, key, 'register');
    return PreparedAuthSession.fromLoginBody(
      body,
      accountKeySeed: key.encodedSeed,
    );
  }
}

final deviceAuthRepositoryProvider = Provider<DeviceAuthRepository>(
  (ref) => DeviceAuthRepository(ref.watch(apiClientProvider)),
);
