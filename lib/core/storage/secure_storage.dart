import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/api_constants.dart';

/// Wrapper around flutter_secure_storage for JWT + refresh token.
class SecureStorage {
  const SecureStorage(this._storage);

  final FlutterSecureStorage _storage;

  // JWT
  Future<String?> readJwt() => _storage.read(key: StorageKeys.jwt);
  Future<void> writeJwt(String token) =>
      _storage.write(key: StorageKeys.jwt, value: token);
  Future<void> deleteJwt() => _storage.delete(key: StorageKeys.jwt);

  Future<String?> readRefreshToken() =>
      _storage.read(key: StorageKeys.refreshToken);
  Future<void> writeRefreshToken(String token) =>
      _storage.write(key: StorageKeys.refreshToken, value: token);
  Future<void> deleteRefreshToken() =>
      _storage.delete(key: StorageKeys.refreshToken);

  Future<String?> readFcmToken() => _storage.read(key: StorageKeys.fcmToken);
  Future<void> writeFcmToken(String token) =>
      _storage.write(key: StorageKeys.fcmToken, value: token);
  Future<void> deleteFcmToken() => _storage.delete(key: StorageKeys.fcmToken);

  Future<String?> readMessageVaultIdentity() =>
      _storage.read(key: StorageKeys.messageVaultIdentity);
  Future<void> writeMessageVaultIdentity(String value) =>
      _storage.write(key: StorageKeys.messageVaultIdentity, value: value);
  Future<void> deleteMessageVaultIdentity() =>
      _storage.delete(key: StorageKeys.messageVaultIdentity);

  Future<String?> readMessagingDeviceIdentity() =>
      _storage.read(key: StorageKeys.messagingDeviceIdentity);
  Future<void> writeMessagingDeviceIdentity(String value) =>
      _storage.write(key: StorageKeys.messagingDeviceIdentity, value: value);

  Future<void> clearAll() => _storage.deleteAll();
}
