import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../auth/email/email_auth_repository.dart';
import '../password/password_repository.dart';

/// Adds a first email to an account that has none (`/api/me/email*`, server
/// 0177), optionally with a password in the same step. The code goes to the
/// address being added. An address another account holds is refused by the
/// server and never merged.
class AccountEmailRepository {
  const AccountEmailRepository(this._client, this._errors);

  final ApiClient _client;

  /// Borrowed for its error mapping: refusals arrive as [EmailAuthException].
  final PasswordRepository _errors;

  Future<EmailCodeSent> sendCode(String email) => _errors.guard(() async {
    final res = await _client.dio.post<Map<String, dynamic>>(
      ApiConstants.meEmailCode,
      data: {'email': email.trim()},
    );
    final info = unwrapApiData<Map<String, dynamic>?>(res) ?? const {};
    return EmailCodeSent(
      maskedEmail: info['email']?.toString() ?? '',
      resendIn: Duration(seconds: (info['resend_in'] as num?)?.toInt() ?? 60),
    );
  });

  Future<void> confirm({
    required String email,
    required String code,
    String password = '',
  }) => _errors.guard(
    () => _client.dio.put<Map<String, dynamic>>(
      ApiConstants.meEmail,
      data: {
        'email': email.trim(),
        'code': code,
        if (password.isNotEmpty) 'password': password,
      },
    ),
  );
}

final accountEmailRepositoryProvider = Provider<AccountEmailRepository>(
  (ref) => AccountEmailRepository(
    ref.watch(apiClientProvider),
    ref.watch(passwordRepositoryProvider),
  ),
);
