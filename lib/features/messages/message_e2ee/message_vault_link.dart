part of 'message_vault.dart';

const _linkAad = 'ababilx-message-device-link-v1';

/// Moving this account's message identity onto another device.
///
/// The new device mints an ephemeral key pair and draws the public half into a
/// QR. A device that already holds the identity reads that key with its camera
/// — never from the server — and seals the identity against it. What travels
/// through AbabilX is therefore ciphertext for a key AbabilX has never seen,
/// which is what lets the whole scheme work with no PIN and no server-side copy
/// of anyone's private key.
extension MessageVaultLink on MessageVault {
  /// New device: the ephemeral pair this link will be sealed against.
  P256KeyPair newLinkEphemeral() => P256Ecdh.newKeyPair();

  /// The QR's `k` parameter: the ephemeral public JWK, base64url'd.
  String encodeLinkPublicKey(P256KeyPair ephemeral) =>
      _b64(utf8.encode(jsonEncode(_publicJwkFromIdentity(ephemeral))));

  Map<String, dynamic> decodeLinkPublicKey(String param) =>
      Map<String, dynamic>.from(jsonDecode(utf8.decode(_bytes(param))) as Map);

  /// Six digits over the ephemeral key so both screens can be compared by eye.
  /// Byte-identical to the web client's derivation, or the codes would differ
  /// across platforms and the check would be worse than useless.
  Future<String> linkVerificationCode(Map<String, dynamic> publicJwk) async {
    final digest = await Sha256().hash(
      utf8.encode('${publicJwk['crv']}.${publicJwk['x']}.${publicJwk['y']}'),
    );
    final b = digest.bytes;
    final value = ((b[0] << 16) | (b[1] << 8) | b[2]) % 1000000;
    return value.toString().padLeft(6, '0');
  }

  /// Approving device: seal this device's identity for the scanned device
  /// alone, under a fresh ephemeral pair so the long-term identity key is never
  /// used directly as an agreement key.
  Future<Map<String, dynamic>> sealIdentityForDevice(
    Map<String, dynamic> scannedPublicJwk,
  ) async {
    final identity = _identity;
    if (identity == null) {
      throw StateError('This device has no message identity to share');
    }
    final ephemeral = P256Ecdh.newKeyPair();
    final nonce = _random(12);
    final wrappingKey = await _envelopeKey(ephemeral, scannedPublicJwk);
    final box = await _aes.encrypt(
      utf8.encode(jsonEncode(_privateJwkFromIdentity(identity))),
      secretKey: wrappingKey,
      nonce: nonce,
      aad: utf8.encode(_linkAad),
    );
    return {
      'ephemeral_public_key': _publicJwkFromIdentity(ephemeral),
      'nonce': _b64(nonce),
      'ciphertext': _b64(_boxBytes(box)),
    };
  }

  /// New device: open the envelope with the ephemeral key kept in memory.
  ///
  /// The public key is taken from the server rather than the envelope, so a
  /// tampered envelope cannot quietly install some other identity — it simply
  /// stops matching and every conversation key stays unreadable, which is the
  /// loud failure worth having.
  Future<void> adoptLinkedIdentity(
    Map<String, dynamic> envelope,
    P256KeyPair ephemeral,
  ) async {
    final status = await _repo.getE2eeVault();
    if (status['exists'] != true) {
      throw StateError('This account has no secure messages yet');
    }
    final vault = Map<String, dynamic>.from(status['vault'] as Map);
    final wrappingKey = await _envelopeKey(
      ephemeral,
      Map<String, dynamic>.from(envelope['ephemeral_public_key'] as Map),
    );
    final clear = await _aes.decrypt(
      _box(envelope['ciphertext'] as String, envelope['nonce'] as String),
      secretKey: wrappingKey,
      aad: utf8.encode(_linkAad),
    );
    final privateJwk = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(clear)) as Map,
    );
    _identity = _identityFromJwk(privateJwk);
    _publicJwk = Map<String, dynamic>.from(vault['public_key'] as Map);
    _keys.clear();
    await _saveTrustedIdentity(privateJwk, _publicJwk!);
    if (vault['wrapped_private_key'] != null) {
      try {
        await _repo.deleteE2eeWrappedKey();
      } catch (_) {
        // Best effort. The next unlock on any device tries again.
      }
    }
  }
}
