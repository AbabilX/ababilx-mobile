part of 'message_vault.dart';

/// Wire-format helpers. Every value crossing the API is base64url without
/// padding and every AES-GCM ciphertext is `ciphertext || 16-byte tag`, which
/// is exactly what WebCrypto emits on the web client.
extension MessageVaultCodec on MessageVault {
  Future<SecretKey> _pinKey(String pin, List<int> salt, int iterations) =>
      Pbkdf2.hmacSha256(
        iterations: iterations,
        bits: 256,
      ).deriveKeyFromPassword(password: pin, nonce: salt);

  P256KeyPair _identityFromJwk(Map<String, dynamic> jwk) => P256KeyPair(
    d: P256Ecdh.encodeCoordinate(
      P256Ecdh.decodeCoordinate(_bytes(jwk['d'] as String)),
    ),
    x: P256Ecdh.encodeCoordinate(
      P256Ecdh.decodeCoordinate(_bytes(jwk['x'] as String)),
    ),
    y: P256Ecdh.encodeCoordinate(
      P256Ecdh.decodeCoordinate(_bytes(jwk['y'] as String)),
    ),
  );

  Map<String, dynamic> _publicJwkFromIdentity(P256KeyPair key) => {
    'kty': 'EC',
    'crv': 'P-256',
    'x': _b64(key.x),
    'y': _b64(key.y),
    'ext': true,
    'key_ops': <String>[],
  };

  SecretBox _box(String cipherText, String nonce) {
    final all = _bytes(cipherText);
    return SecretBox(
      all.sublist(0, all.length - 16),
      nonce: _bytes(nonce),
      mac: Mac(all.sublist(all.length - 16)),
    );
  }

  List<int> _boxBytes(SecretBox box) => [...box.cipherText, ...box.mac.bytes];

  List<int> _random(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }

  String _b64(List<int> bytes) => base64Url.encode(bytes).replaceAll('=', '');

  List<int> _bytes(String value) =>
      base64Url.decode(base64Url.normalize(value));

  void _validatePin(String pin) {
    if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
      throw ArgumentError('Use a 6-digit message PIN');
    }
  }
}
