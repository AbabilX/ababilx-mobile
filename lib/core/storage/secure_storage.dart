import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/api_constants.dart';

/// Wrapper around flutter_secure_storage for JWT + FCM token management.
class SecureStorage {
  const SecureStorage(this._storage);

  final FlutterSecureStorage _storage;

  // JWT
  Future<String?> readJwt() => _storage.read(key: StorageKeys.jwt);
  Future<void> writeJwt(String token) =>
      _storage.write(key: StorageKeys.jwt, value: token);
  Future<void> deleteJwt() => _storage.delete(key: StorageKeys.jwt);

  // FCM token (cached locally for re-registration on token refresh)
  Future<String?> readFcmToken() => _storage.read(key: StorageKeys.fcmToken);
  Future<void> writeFcmToken(String token) =>
      _storage.write(key: StorageKeys.fcmToken, value: token);
  Future<void> deleteFcmToken() => _storage.delete(key: StorageKeys.fcmToken);

  Future<void> clearAll() => _storage.deleteAll();
}
