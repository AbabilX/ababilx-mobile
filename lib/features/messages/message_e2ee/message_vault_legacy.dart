part of 'message_vault.dart';

/// The retired PIN scheme, kept only so accounts created under it can leave it.
///
/// Their identity key sits on the server wrapped by six digits — a keyspace of
/// a million, which is no protection at all against anyone holding the database
/// — so this unlocks it once, writes it to the device, and deletes the server's
/// copy. Nothing here creates a PIN vault; that path is gone.
extension MessageVaultLegacy on MessageVault {
  Future<void> unlock(String pin) async {
    _validatePin(pin);
    final status = await _repo.getE2eeVault();
    if (status['exists'] != true) {
      throw StateError('Set up your message PIN first');
    }
    final vault = Map<String, dynamic>.from(status['vault'] as Map);
    final wrapped = Map<String, dynamic>.from(
      vault['wrapped_private_key'] as Map,
    );
    try {
      final key = await _pinKey(
        pin,
        _bytes(vault['kdf_salt'] as String),
        (vault['kdf_iterations'] as num).toInt(),
      );
      final clear = await _aes.decrypt(
        _box(wrapped['ciphertext'] as String, wrapped['nonce'] as String),
        secretKey: key,
        aad: utf8.encode(_vaultAad),
      );
      final jwk = Map<String, dynamic>.from(
        jsonDecode(utf8.decode(clear)) as Map,
      );
      _identity = _identityFromJwk(jwk);
      _publicJwk = Map<String, dynamic>.from(vault['public_key'] as Map);
      _keys.clear();
      await _saveTrustedIdentity(
        _privateJwkFromIdentity(_identity!),
        _publicJwk!,
      );
    } catch (_) {
      throw StateError('Incorrect message PIN');
    }
    // The key is on the device now, so the six-digit wrapping on the server is
    // pure liability: a million-guess keyspace protecting a real private key.
    // Dropping it is the whole point of this last unlock.
    try {
      await _repo.deleteE2eeWrappedKey();
    } catch (_) {
      // Best effort; ensureIdentity retries on the next launch.
    }
  }
}
