import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/api_constants.dart';

/// Wrapper around flutter_secure_storage for JWT + refresh token.
class SecureStorage {
  const SecureStorage(this._storage);

  final FlutterSecureStorage _storage;

  Future<String?> readOutboxKey() => _storage.read(key: 'local_outbox_key_v1');
  Future<void> writeOutboxKey(String value) =>
      _storage.write(key: 'local_outbox_key_v1', value: value);

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

  Future<String?> readLocalDataOwnerUserId() =>
      _storage.read(key: StorageKeys.localDataOwnerUserId);
  Future<void> writeLocalDataOwnerUserId(String userId) =>
      _storage.write(key: StorageKeys.localDataOwnerUserId, value: userId);

  Future<String?> readRecoveryCode(String identityId) =>
      _storage.read(key: 'message_recovery_code_$identityId');
  Future<void> writeRecoveryCode(String identityId, String code) =>
      _storage.write(key: 'message_recovery_code_$identityId', value: code);

  Future<String?> readPendingRecovery(String userId) =>
      _storage.read(key: 'pending_recovery_v1_$userId');
  Future<void> writePendingRecovery(String userId, String value) =>
      _storage.write(key: 'pending_recovery_v1_$userId', value: value);
  Future<void> deletePendingRecovery(String userId) =>
      _storage.delete(key: 'pending_recovery_v1_$userId');

  Future<String?> readAccountKey() =>
      _storage.read(key: StorageKeys.accountKey);
  Future<void> writeAccountKey(String seed) =>
      _storage.write(key: StorageKeys.accountKey, value: seed);
  Future<void> deleteAccountKey() =>
      _storage.delete(key: StorageKeys.accountKey);

  /// Ends authentication without destroying this phone's message archive.
  Future<void> clearAuthSession() async {
    await deleteJwt();
    await deleteRefreshToken();
  }

  /// Account switch / explicit full reset only. Exported MediaStore and Files
  /// copies are outside secure storage and deliberately survive this.
  Future<void> clearAllPrivateData() => _storage.deleteAll();
}
