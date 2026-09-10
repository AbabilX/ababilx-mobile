part of 'message_vault.dart';

/// Bringing this device's own stored identity back into memory.
///
/// Split from `message_vault_identity.dart` only for size; the rule that
/// matters lives on [MessageVaultRestore.restoreTrustedIdentity].
extension MessageVaultRestore on MessageVault {
  /// Restores the identity protected by this device's OS secure storage,
  /// checking with the server that it is still the one the account uses.
  /// It is intentionally erased on logout and by an app uninstall.
  ///
  /// **An unreachable server is not a wrong key.** This used to lock the vault
  /// whenever anything at all threw, so an offline launch tore down an
  /// identity that was sitting in this device's keystore and perfectly valid —
  /// which is half of why every message read "Unable to decrypt this message"
  /// with no connection. The staleness check is advisory: it can only be
  /// trusted when the server actually answers, so a failed call falls through
  /// to the local identity instead of discarding it.
  Future<bool> restoreTrustedIdentity() async {
    try {
      final saved = await _storage.readMessageVaultIdentity();
      if (saved == null) {
        lock();
        return false;
      }
      final data = Map<String, dynamic>.from(jsonDecode(saved) as Map);
      final localPublic = Map<String, dynamic>.from(data['public_key'] as Map);
      Map<String, dynamic>? status;
      try {
        status = await _repo.getE2eeVault();
      } catch (_) {
        // Offline, or the server is unreachable. Nothing has been learned
        // about whether this identity is current, so nothing is thrown away.
        status = null;
      }
      if (status != null) {
        if (status['exists'] != true) {
          lock();
          return false;
        }
        final serverPublic = Map<String, dynamic>.from(
          (status['vault'] as Map)['public_key'] as Map,
        );
        // The identity was replaced elsewhere, so this copy is dead: it would
        // fail every decryption from here on. Only a real answer may say so.
        if (serverPublic['x'] != localPublic['x'] ||
            serverPublic['y'] != localPublic['y']) {
          lock();
          await _storage.deleteMessageVaultIdentity();
          return false;
        }
      }
      _identity = _identityFromJwk(
        Map<String, dynamic>.from(data['private_key'] as Map),
      );
      _publicJwk = localPublic;
      _clearKeyMemory();
      return true;
    } catch (_) {
      lock();
      return false;
    }
  }

  /// Same restore without the server round-trip, for the FCM background
  /// isolate: a push has seconds to decrypt, and the public-key comparison is
  /// only a staleness check — a rotated identity simply fails the AES-GCM tag
  /// and the notification falls back to its placeholder.
  Future<bool> restoreTrustedIdentityOffline() async {
    try {
      final saved = await _storage.readMessageVaultIdentity();
      if (saved == null) return false;
      final data = Map<String, dynamic>.from(jsonDecode(saved) as Map);
      _identity = _identityFromJwk(
        Map<String, dynamic>.from(data['private_key'] as Map),
      );
      _publicJwk = Map<String, dynamic>.from(data['public_key'] as Map);
      _clearKeyMemory();
      return true;
    } catch (_) {
      lock();
      return false;
    }
  }
}
