part of 'message_vault.dart';

/// Vault identity: getting the account's message key onto this phone.
///
/// The key is minted here and the server never sees it. What the server keeps
/// is a copy wrapped by a 256-bit recovery code, generated on the device and
/// shown once — ciphertext it cannot open. That is what lets a second device
/// catch up without giving up end-to-end encryption.
///
/// The unlock path is in `message_vault_recover.dart`; the last-resort identity
/// swap is in `message_vault_reset.dart`.
extension MessageVaultIdentity on MessageVault {
  /// Mints a recovery code for an identity, publishes the wrapped key, and
  /// stages the code for the setup screen to show.
  Future<VaultIdentityState> _provisionRecovery(
    P256KeyPair identity,
    Map<String, dynamic> publicJwk,
  ) async {
    final code = RecoveryKey.generateCode();
    final vault = await RecoveryKey.wrap(
      _privateJwkFromIdentity(identity),
      code,
    );
    await _repo.putE2eeRecoveryVault(publicJwk, vault.toJson());
    await _adopt(identity, publicJwk);
    _pendingRecoveryCode = RecoveryKey.format(code);
    return VaultIdentityState.setup;
  }

  /// Brings secure messages up, asking for nothing when it can.
  ///
  /// A first launch mints the identity here, wraps it under a fresh recovery
  /// code and shows that code once. A phone that already holds the key just
  /// loads it. A phone that does not has to be given the key by its owner —
  /// there is nowhere else it could come from, which is the point.
  Future<VaultIdentityState> ensureIdentity() async {
    final status = await _repo.getE2eeVault();

    if (status['exists'] != true) {
      final identity = P256Ecdh.newKeyPair();
      final publicJwk = _publicJwkFromIdentity(identity);
      try {
        return await _provisionRecovery(identity, publicJwk);
      } catch (_) {
        // Two devices setting up at once both see an empty account and both
        // mint; the server keeps whichever landed first. Re-read and take the
        // normal path rather than reporting a race that resolved itself.
        final settled = await _repo.getE2eeVault();
        if (settled['exists'] != true) rethrow;
        return VaultIdentityState.unlock;
      }
    }

    final vault = Map<String, dynamic>.from(status['vault'] as Map);
    final publicJwk = Map<String, dynamic>.from(vault['public_key'] as Map);

    if (await _adoptStoredIdentity(publicJwk)) {
      // An identity from before recovery codes has no way onto a second device.
      // This phone holds it, so wrap it under a new code and show that code —
      // the one moment this can be fixed without asking for anything.
      if (vault['recovery'] == null) {
        try {
          return await _provisionRecovery(_identity!, publicJwk);
        } catch (_) {
          // A working chat matters more; the next launch tries again.
        }
      }
      return VaultIdentityState.ready;
    }
    return VaultIdentityState.unlock;
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
      _clearKeyMemory();
      return true;
    } catch (_) {
      lock();
      return false;
    }
  }

  /// Puts an identity into memory and into this device's secure storage.
  Future<void> _adopt(
    P256KeyPair identity,
    Map<String, dynamic> publicJwk,
  ) async {
    _identity = identity;
    _publicJwk = publicJwk;
    _clearKeyMemory();
    await _saveTrustedIdentity(_privateJwkFromIdentity(identity), publicJwk);
  }

  void lock() {
    _identity = null;
    _publicJwk = null;
    _clearKeyMemory();
  }

  Future<void> _saveTrustedIdentity(
    Map<String, dynamic> privateJwk,
    Map<String, dynamic> publicJwk,
  ) => _storage.writeMessageVaultIdentity(
    jsonEncode({'private_key': privateJwk, 'public_key': publicJwk}),
  );
}
