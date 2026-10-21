import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../data/app_key.dart';
import '../data/auth_session.dart';

/// A refusal the server explained: [code] to branch on, [message] to show.
class EmailAuthException implements Exception {
  const EmailAuthException(this.code, this.message, {this.retryAfter});

  final String code;
  final String message;
  final Duration? retryAfter;

  @override
  String toString() => message;
}

/// Where a code went and when another may be asked for.
class EmailCodeSent {
  const EmailCodeSent({required this.maskedEmail, required this.resendIn});

  final String maskedEmail;
  final Duration resendIn;
}

/// Email + password sign-in against `/auth/email/*`. Every call that ends in
/// a session returns a [PreparedAuthSession] for AuthNotifier to adopt, so the
/// account-switch check covers it exactly as it covers Google.
class EmailAuthRepository {
  EmailAuthRepository(this._client);

  final ApiClient _client;

  static const _clientName = 'mobile';

  static const _appKey = ababilxAppKey;

  Future<Response<Map<String, dynamic>>> _post(
    String path,
    Map<String, dynamic> data,
  ) => _client.dio.post<Map<String, dynamic>>(
    path,
    data: data,
    options: Options(headers: {if (_appKey.isNotEmpty) 'X-APP-KEY': _appKey}),
  );

  Future<EmailCodeSent> signUp({
    required String name,
    required String email,
    required String password,
  }) => _codeRequest(ApiConstants.emailSignup, {
    'name': name,
    'email': email,
    'password': password,
  });

  Future<PreparedAuthSession> verifySignUp({
    required String email,
    required String code,
  }) => _session(ApiConstants.emailVerify, {
    'email': email,
    'code': code,
    'client': _clientName,
  });

  Future<PreparedAuthSession> signIn({
    required String email,
    required String password,
  }) => _session(ApiConstants.emailLogin, {
    'email': email,
    'password': password,
    'client': _clientName,
  });

  Future<EmailCodeSent> requestReset({required String email}) =>
      _codeRequest(ApiConstants.emailReset, {'email': email});

  Future<PreparedAuthSession> confirmReset({
    required String email,
    required String code,
    required String password,
  }) => _session(ApiConstants.emailResetConfirm, {
    'email': email,
    'code': code,
    'password': password,
    'client': _clientName,
  });

  Future<EmailCodeSent> _codeRequest(String path, Map<String, dynamic> data) =>
      _guard(() async {
        final response = await _post(path, data);
        final body = response.data?['data'];
        final info = body is Map ? body : const {};
        return EmailCodeSent(
          maskedEmail: info['email']?.toString() ?? data['email'].toString(),
          resendIn: Duration(
            seconds: (info['resend_in'] as num?)?.toInt() ?? 60,
          ),
        );
      });

  Future<PreparedAuthSession> _session(
    String path,
    Map<String, dynamic> data,
  ) => _guard(() async {
    final response = await _post(path, data);
    return PreparedAuthSession.fromLoginBody(response.data ?? const {});
  });

  /// Turns the server's structured refusal into an [EmailAuthException];
  /// anything else (offline, timeout) is rethrown for the generic copy.
  Future<T> _guard<T>(Future<T> Function() call) async {
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

final emailAuthRepositoryProvider = Provider<EmailAuthRepository>(
  (ref) => EmailAuthRepository(ref.watch(apiClientProvider)),
);
