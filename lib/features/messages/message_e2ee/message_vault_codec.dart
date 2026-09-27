part of 'message_vault.dart';

class EncryptedDmPayload {
  const EncryptedDmPayload({
    required this.encryptedBody,
    required this.nonce,
    required this.keyVersion,
  });
  final String encryptedBody;
  final String nonce;
  final int keyVersion;
}

/// Wire-format helpers. Every value crossing the API is base64url without
/// padding and every AES-GCM ciphertext is `ciphertext || 16-byte tag`, which
/// is exactly what WebCrypto emits on the web client.
extension MessageVaultCodec on MessageVault {
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

  /// The private JWK as WebCrypto will accept it back.
  ///
  /// This deliberately does not reuse the public JWK's `key_ops`: a public ECDH
  /// key declares no usages, and importing a *private* key that says
  /// `key_ops: []` while asking for `deriveBits` is rejected outright by
  /// WebCrypto. Getting this wrong breaks phone-to-browser linking only, which
  /// is exactly the case a phone can never test on its own.
  Map<String, dynamic> _privateJwkFromIdentity(P256KeyPair key) => {
    'kty': 'EC',
    'crv': 'P-256',
    'x': _b64(key.x),
    'y': _b64(key.y),
    'd': _b64(key.d),
    'ext': true,
    'key_ops': <String>['deriveBits'],
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
}
