import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// One sealed piece of an archive.
class ArchiveChunk {
  const ArchiveChunk({required this.nonce, required this.ciphertext});

  final Uint8List nonce;

  /// Ciphertext with the 16-byte GCM tag appended, the same layout
  /// [RecoveryKey] uses, so both sides of the app split it identically.
  final Uint8List ciphertext;
}

/// The key an encrypted history archive is sealed with.
///
/// **Rooted in the identity private scalar, not in the recovery code**, and the
/// distinction is not cosmetic. The code is never persisted anywhere — see the
/// rule in `message_vault.dart`, which keeps a freshly minted code in a single
/// field and nulls it on first read, because anything durable would leave a
/// key-equivalent on disk. So a backup that derived from the code directly
/// could only ever run while the user was typing it, which is not when a backup
/// should run.
///
/// The code is still the root, transitively: code -> `RecoveryKey.unwrap` ->
/// identity -> archive key. That chain has two useful properties. Rotating the
/// code re-wraps the *same* identity, so `regenerateRecoveryCode` cannot orphan
/// an archive. And starting fresh mints a *new* identity, so old archives
/// become unreadable at exactly the moment old messages do — one rule, not two.
///
/// Never seal an archive with [RecoveryKey.deriveKey]. Same input, different
/// purpose: a distinct `info` string is what keeps the two key usages from
/// being the same bytes.
class ArchiveKey {
  static const _info = 'ababilx-archive-key-v1';
  static const _aad = 'ababilx-archive-v1';
  static const version = 1;
  static const saltBytes = 32;
  static const _nonceBytes = 12;

  static final _aes = AesGcm.with256bits();

  static Uint8List newSalt() => _random(saltBytes);

  /// HKDF-SHA256 over the 32-byte private scalar. No stretching, for the same
  /// reason the recovery code needs none: the input is already full entropy.
  static Future<SecretKey> derive(List<int> identityScalar, List<int> salt) {
    if (identityScalar.length != 32) {
      throw ArgumentError('identity scalar must be 32 bytes');
    }
    return Hkdf(hmac: Hmac.sha256(), outputLength: 32).deriveKey(
      secretKey: SecretKey(identityScalar),
      nonce: salt,
      info: utf8.encode(_info),
    );
  }

  /// Seals one chunk, binding its POSITION into the AAD.
  ///
  /// Without that binding an archive is a bag of independently valid chunks:
  /// anyone holding the ciphertext could drop the last one, or swap two, and
  /// every tag would still verify. Binding the index makes reordering and
  /// truncation fail the tag check instead of silently producing a shorter,
  /// plausible history.
  static Future<ArchiveChunk> seal(
    SecretKey key,
    int index,
    List<int> plaintext,
  ) async {
    final nonce = _random(_nonceBytes);
    final box = await _aes.encrypt(
      plaintext,
      secretKey: key,
      nonce: nonce,
      aad: chunkAad(index),
    );
    return ArchiveChunk(
      nonce: nonce,
      ciphertext: Uint8List.fromList([...box.cipherText, ...box.mac.bytes]),
    );
  }

  static Future<List<int>> open(SecretKey key, int index, ArchiveChunk chunk) {
    final all = chunk.ciphertext;
    return _aes.decrypt(
      SecretBox(
        all.sublist(0, all.length - 16),
        nonce: chunk.nonce,
        mac: Mac(all.sublist(all.length - 16)),
      ),
      secretKey: key,
      aad: chunkAad(index),
    );
  }

  /// Exposed so the test can pin it: a change here silently makes every
  /// existing archive unopenable, with no error that names the cause.
  static List<int> chunkAad(int index) => utf8.encode('$_aad:$index');

  static Uint8List _random(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }
}
