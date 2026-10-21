import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage.dart';
import 'device_account_key.dart';
import 'device_auth_repository.dart';

/// A key-only account has no password to type and no Google to tap: when its
/// refresh token is refused (a month unused, a revoked session), the key on
/// this phone signs it back in. Without this the account would be lost the
/// first time the phone sat in a drawer for 30 days.
///
/// Only ever signs in as the account this phone's data belongs to — a
/// leftover key from another account answers [RefreshOutcome.rejected].
/// [dio] must be bare (no interceptors), or a 401 here would recurse.
Future<RefreshOutcome> reloginWithAccountKey(
  Dio dio,
  SecureStorage storage,
) async {
  final key = await DeviceAccountKey.decode(await storage.readAccountKey());
  if (key == null) return RefreshOutcome.rejected;
  try {
    final body = await deviceSignIn(dio, key, 'login');
    final access = (body['access_token'] ?? body['token']) as String?;
    final refresh = body['refresh_token'] as String?;
    final user = body['user'];
    final userId = user is Map ? user['id']?.toString() ?? '' : '';
    final owner = (await storage.readLocalDataOwnerUserId())?.trim() ?? '';
    if (access == null || refresh == null || userId.isEmpty) {
      return RefreshOutcome.unavailable;
    }
    if (owner.isNotEmpty && owner != userId) return RefreshOutcome.rejected;
    await storage.writeRefreshToken(refresh);
    await storage.writeJwt(access);
    return RefreshOutcome.refreshed;
  } on DeviceAuthException catch (error) {
    // invalid_credentials: no live account holds this key any more.
    return error.code == 'invalid_credentials'
        ? RefreshOutcome.rejected
        : RefreshOutcome.unavailable;
  } on DioException catch (error) {
    return refreshOutcomeForStatus(error.response?.statusCode);
  } catch (_) {
    return RefreshOutcome.unavailable;
  }
}
