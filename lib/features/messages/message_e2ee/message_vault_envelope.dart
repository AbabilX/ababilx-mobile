part of 'message_vault.dart';

/// Sealing a conversation key to one member, and opening one sealed to us.
///
/// Recipient-bound: the user id is the AAD, so an envelope cannot be re-pointed
/// at a different member by moving the row. Nothing here knows how many members
/// there are — which is why the same code serves a DM and a group.
extension MessageVaultEnvelope on MessageVault {
  Future<Map<String, dynamic>> _wrapKey(
    SecretKey key,
    String recipient,
    Map<String, dynamic> publicJwk,
  ) async {
    final ephemeral = P256Ecdh.newKeyPair();
    final nonce = _random(12);
    final wrappingKey = await _envelopeKey(ephemeral, publicJwk);
    final box = await _aes.encrypt(
      await key.extractBytes(),
      secretKey: wrappingKey,
      nonce: nonce,
      aad: utf8.encode('ababilx-dm-key-v1:$recipient'),
    );
    return {
      'ephemeral_public_key': _publicJwkFromIdentity(ephemeral),
      'nonce': _b64(nonce),
      'ciphertext': _b64(_boxBytes(box)),
    };
  }

  Future<SecretKey> _unwrapKey(
    Map<String, dynamic> envelope,
    String userId,
  ) async {
    final identity = _identity;
    if (identity == null) {
      throw StateError('Secure messages are not ready on this device yet');
    }
    final key = await _envelopeKey(
      identity,
      Map<String, dynamic>.from(envelope['ephemeral_public_key'] as Map),
    );
    final clear = await _aes.decrypt(
      _box(envelope['ciphertext'] as String, envelope['nonce'] as String),
      secretKey: key,
      aad: utf8.encode('ababilx-dm-key-v1:$userId'),
    );
    return SecretKey(clear);
  }

  /// SHA-256 over the raw ECDH X coordinate — the same derivation the web
  /// client performs with `deriveBits(256)` + `digest("SHA-256")`.
  Future<SecretKey> _envelopeKey(
    P256KeyPair private,
    Map<String, dynamic> remote,
  ) async {
    final shared = P256Ecdh.sharedSecretX(
      privateD: private.d,
      remoteX: _bytes(remote['x'] as String),
      remoteY: _bytes(remote['y'] as String),
    );
    return SecretKey((await Sha256().hash(shared)).bytes);
  }
}
