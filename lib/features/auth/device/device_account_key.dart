import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';

/// The Ed25519 key that IS a key-only account ("Start New Chat"). The server
/// keeps only its public half and finds the account by it; this phone keeps
/// the 32-byte seed in secure storage. No email, no password: lose the seed
/// and the account is gone, which is why sign-out warns so loudly.
///
/// Pure Dart on purpose (see memory: platform crypto drifted from the
/// server's on ECDH). Pinned against the Go server by
/// test/features/auth/device_account_key_test.dart.
class DeviceAccountKey {
  DeviceAccountKey._(this.seed, this._keyPair, this.publicKey);

  /// What the server signs over: prefix, purpose, `|`, nonce bytes.
  static const signaturePrefix = 'ababilx-device-auth-v1|';

  static final _ed25519 = DartEd25519();

  final List<int> seed;
  final SimpleKeyPair _keyPair;
  final List<int> publicKey;

  static Future<DeviceAccountKey> generate() {
    final random = Random.secure();
    return fromSeed(List<int>.generate(32, (_) => random.nextInt(256)));
  }

  static Future<DeviceAccountKey> fromSeed(List<int> seed) async {
    if (seed.length != 32) throw ArgumentError('seed must be 32 bytes');
    final pair = await _ed25519.newKeyPairFromSeed(seed);
    final public = await pair.extractPublicKey();
    return DeviceAccountKey._(List.unmodifiable(seed), pair, public.bytes);
  }

  /// Reads a seed as [encodedSeed] wrote it; null when absent or unreadable.
  static Future<DeviceAccountKey?> decode(String? stored) async {
    if (stored == null || stored.isEmpty) return null;
    try {
      return await fromSeed(base64Url.decode(base64Url.normalize(stored)));
    } catch (_) {
      return null;
    }
  }

  String get encodedSeed => base64Url.encode(seed);

  String get encodedPublicKey => encodeBytes(publicKey);

  static List<int> signedMessage(String purpose, List<int> nonce) => [
    ...utf8.encode('$signaturePrefix$purpose|'),
    ...nonce,
  ];

  Future<List<int>> sign(String purpose, List<int> nonce) async {
    final signature = await _ed25519.sign(
      signedMessage(purpose, nonce),
      keyPair: _keyPair,
    );
    return signature.bytes;
  }

  /// Unpadded base64url, the server's wire form.
  static String encodeBytes(List<int> bytes) =>
      base64Url.encode(bytes).replaceAll('=', '');

  static List<int> decodeBytes(String value) =>
      base64Url.decode(base64Url.normalize(value));
}
