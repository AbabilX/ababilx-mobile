import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../auth/email/email_auth_repository.dart';

/// Where the account stands: [hasPassword] decides "Set" or "Change", and
/// [canSet] is false when its email cannot receive a code (or belongs to
/// another account), so nothing may be put on it.
class PasswordStatus {
  const PasswordStatus({
    required this.hasPassword,
    required this.email,
    required this.canSet,
  });

  factory PasswordStatus.fromJson(Map<String, dynamic> json) => PasswordStatus(
    hasPassword: json['has_password'] == true,
    email: json['email']?.toString() ?? '',
    canSet: json['can_set'] == true,
  );

  final bool hasPassword;
  final String email;
  final bool canSet;
}

/// Settings → Password against `/api/me/password*` (signed in, no
/// X-APP-KEY). The code always goes to the account's OWN inbox — the server
/// picks the address — which is what makes it safe to put a password on an
/// account Google made. Setting one keeps this session signed in.
class PasswordRepository {
  const PasswordRepository(this._client);

  final ApiClient _client;

  Future<PasswordStatus> status() => guard(() async {
    final res = await _client.dio.get<Map<String, dynamic>>(
      ApiConstants.mePassword,
    );
    return PasswordStatus.fromJson(unwrapApiData<Map<String, dynamic>>(res));
  });

  Future<EmailCodeSent> sendCode() => guard(() async {
    final res = await _client.dio.post<Map<String, dynamic>>(
      ApiConstants.mePasswordCode,
    );
    final info = unwrapApiData<Map<String, dynamic>?>(res) ?? const {};
    return EmailCodeSent(
      maskedEmail: info['email']?.toString() ?? '',
      resendIn: Duration(seconds: (info['resend_in'] as num?)?.toInt() ?? 60),
    );
  });

  Future<void> setPassword({required String code, required String password}) =>
      guard(
        () => _client.dio.put<Map<String, dynamic>>(
          ApiConstants.mePassword,
          data: {'code': code, 'password': password},
        ),
      );

  /// A refusal with a `code` becomes an [EmailAuthException], so the screen
  /// reuses the email sign-in translations (`email_err_<code>`). A wrong code
  /// is a 400 here, never a 401 — under `/api` a 401 signs the phone out.
  Future<T> guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (error) {
      final data = error.response?.data;
      if (data is Map && data['code'] is String) {
        final seconds = (data['retry_after'] as num?)?.toInt();
        throw EmailAuthException(
          data['code'] as String,
          (data['message'] ?? data['error'] ?? '').toString(),
          retryAfter: seconds == null ? null : Duration(seconds: seconds),
        );
      }
      rethrow;
    }
  }
}

final passwordRepositoryProvider = Provider<PasswordRepository>(
  (ref) => PasswordRepository(ref.watch(apiClientProvider)),
);
