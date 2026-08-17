part of 'message_vault.dart';

/// Vault identity: creating it behind a PIN, unlocking it, and restoring it
/// from this device's OS secure storage. The private key never leaves memory
/// except as the PIN-wrapped blob the server stores and the trusted-device
/// record, both of which this extension owns.
extension MessageVaultIdentity on MessageVault {
  Future<bool> hasVault() async =>
      (await _repo.getE2eeVault())['exists'] == true;

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

  Future<void> setup(String pin) async {
    _validatePin(pin);
    final identity = P256Ecdh.newKeyPair();
    final publicJwk = _publicJwkFromIdentity(identity);
    final privateJwk = {...publicJwk, 'd': _b64(identity.d)};
    final salt = _random(16);
    final nonce = _random(12);
    final key = await _pinKey(pin, salt, _iterations);
    final box = await _aes.encrypt(
      utf8.encode(jsonEncode(privateJwk)),
      secretKey: key,
      nonce: nonce,
      aad: utf8.encode(_vaultAad),
    );
    await _repo.putE2eeVault({
      'public_key': publicJwk,
      'wrapped_private_key': {
        'ciphertext': _b64(_boxBytes(box)),
        'nonce': _b64(nonce),
      },
      'kdf_salt': _b64(salt),
      'kdf_iterations': _iterations,
    });
    _identity = identity;
    _publicJwk = publicJwk;
    _keys.clear();
    await _saveTrustedIdentity(privateJwk, publicJwk);
  }

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
      await _saveTrustedIdentity(jwk, _publicJwk!);
    } catch (_) {
      throw StateError('Incorrect message PIN');
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
