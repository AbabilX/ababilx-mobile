part of 'message_vault.dart';

/// Vault identity: creating it on this device and restoring it from the OS
/// secure storage. The private key is generated here and never leaves — the
/// server is told the public half and nothing else — so bringing secure
/// messages up asks the user for nothing at all.
///
/// The retired PIN paths live in `message_vault_legacy.dart`.
extension MessageVaultIdentity on MessageVault {
  /// Restores the identity protected by this device's OS secure storage.
  /// It is intentionally erased on logout and by an app uninstall.
  Future<bool> restoreTrustedIdentity() async {
    try {
      final saved = await _storage.readMessageVaultIdentity();
      if (saved == null) {
        lock();
        return false;
      }
      final data = Map<String, dynamic>.from(jsonDecode(saved) as Map);
      final status = await _repo.getE2eeVault();
      if (status['exists'] != true) {
        lock();
        return false;
      }
      final serverPublic = Map<String, dynamic>.from(
        (status['vault'] as Map)['public_key'] as Map,
      );
      final localPublic = Map<String, dynamic>.from(data['public_key'] as Map);
      if (serverPublic['x'] != localPublic['x'] ||
          serverPublic['y'] != localPublic['y']) {
        lock();
        await _storage.deleteMessageVaultIdentity();
        return false;
      }
      _identity = _identityFromJwk(
        Map<String, dynamic>.from(data['private_key'] as Map),
      );
      _publicJwk = localPublic;
      _keys.clear();
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
      _keys.clear();
      return true;
    } catch (_) {
      lock();
      return false;
    }
  }

  /// Brings secure messages up without asking the user anything.
  ///
  /// A first device mints its own identity and publishes only the public half,
  /// so there is no PIN to choose and nothing on the server worth stealing. A
  /// device that already holds the identity simply loads it. Anything else
  /// needs a human: a link from another device, or the one-time legacy unlock.
  Future<VaultIdentityState> ensureIdentity() async {
    final status = await _repo.getE2eeVault();
    if (status['exists'] != true) {
      final identity = P256Ecdh.newKeyPair();
      final publicJwk = _publicJwkFromIdentity(identity);
      try {
        await _repo.putE2eeIdentity(publicJwk);
      } catch (error) {
        // Two devices setting up at once both see an empty account and both
        // mint; the server keeps whichever landed first and rejects the other.
        // Losing that race is normal, not an error — but only if what is there
        // now is genuinely somebody else's key, so re-read before deciding.
        final settled = await _repo.getE2eeVault();
        if (settled['exists'] != true) rethrow;
        final theirs = Map<String, dynamic>.from(
          (settled['vault'] as Map)['public_key'] as Map,
        );
        if (theirs['x'] != publicJwk['x'] || theirs['y'] != publicJwk['y']) {
          return (settled['vault'] as Map)['wrapped_private_key'] != null
              ? VaultIdentityState.legacy
              : VaultIdentityState.link;
        }
      }
      _identity = identity;
      _publicJwk = publicJwk;
      _keys.clear();
      await _saveTrustedIdentity(_privateJwkFromIdentity(identity), publicJwk);
      return VaultIdentityState.ready;
    }

    final vault = Map<String, dynamic>.from(status['vault'] as Map);
    final publicJwk = Map<String, dynamic>.from(vault['public_key'] as Map);
    final hasWrapped = vault['wrapped_private_key'] != null;

    if (await _adoptStoredIdentity(publicJwk)) {
      // A device that holds the key makes the server's wrapped copy pure risk.
      if (hasWrapped) {
        try {
          await _repo.deleteE2eeWrappedKey();
        } catch (_) {
          // Best effort; the next launch tries again.
        }
      }
      return VaultIdentityState.ready;
    }
    return hasWrapped ? VaultIdentityState.legacy : VaultIdentityState.link;
  }

  /// Loads the identity this device stored, but only if it is still the one the
  /// account uses. A mismatch means the identity was replaced elsewhere, so the
  /// stale copy is dropped rather than left to fail every decryption.
  Future<bool> _adoptStoredIdentity(Map<String, dynamic> publicJwk) async {
    final saved = await _storage.readMessageVaultIdentity();
    if (saved == null) return false;
    try {
      final data = Map<String, dynamic>.from(jsonDecode(saved) as Map);
      final localPublic = Map<String, dynamic>.from(data['public_key'] as Map);
      if (publicJwk['x'] != localPublic['x'] ||
          publicJwk['y'] != localPublic['y']) {
        lock();
        await _storage.deleteMessageVaultIdentity();
        return false;
      }
      _identity = _identityFromJwk(
        Map<String, dynamic>.from(data['private_key'] as Map),
      );
      _publicJwk = localPublic;
      _keys.clear();
      return true;
    } catch (_) {
      lock();
      return false;
    }
  }

  void lock() {
    _identity = null;
    _publicJwk = null;
    _keys.clear();
  }

  Future<void> _saveTrustedIdentity(
    Map<String, dynamic> privateJwk,
    Map<String, dynamic> publicJwk,
  ) => _storage.writeMessageVaultIdentity(
    jsonEncode({'private_key': privateJwk, 'public_key': publicJwk}),
  );
}
