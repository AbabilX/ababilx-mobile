import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'attachment_crypto_format.dart';

/// One chunk of an `ababilx-att-v1` file in and out of AES-256-GCM. The nonce
/// and the AAD come from the chunk's index and whether it is the last one —
/// see [AttachmentCryptoFormat] for why.
abstract final class AttachmentChunkCipher {
  static const _tag = AttachmentCryptoFormat.tagBytes;
  static final _aes = AesGcm.with256bits();

  static Future<SecretBox> seal(
    SecretKey key,
    Uint8List chunk,
    int index, {
    required bool last,
  }) => _aes.encrypt(
    chunk,
    secretKey: key,
    nonce: AttachmentCryptoFormat.chunkNonce(index),
    aad: AttachmentCryptoFormat.chunkAad(index, last: last),
  );

  /// [sealed] is `ciphertext || tag`. Throws the cipher's own authentication
  /// error for a wrong key, a changed byte, a chunk out of place or an object
  /// cut short.
  static Future<List<int>> open(
    SecretKey key,
    Uint8List sealed,
    int index, {
    required bool last,
  }) => _aes.decrypt(
    SecretBox(
      Uint8List.sublistView(sealed, 0, sealed.length - _tag),
      nonce: AttachmentCryptoFormat.chunkNonce(index),
      mac: Mac(Uint8List.sublistView(sealed, sealed.length - _tag)),
    ),
    secretKey: key,
    aad: AttachmentCryptoFormat.chunkAad(index, last: last),
  );

  /// A stated plaintext length has to fit inside the object it describes.
  /// It comes from the sender, so without this a hostile one could make a
  /// reader allocate whatever it named.
  static void checkStatedSize(int plainSize, int objectSize) {
    if (plainSize < 0 || plainSize > objectSize) {
      throw const AttachmentCipherException('stated size does not fit');
    }
  }

  /// `readInto` may return fewer bytes than asked for; a chunk boundary that
  /// drifted by one byte would fail every tag after it.
  static Future<void> readFully(
    RandomAccessFile file,
    Uint8List into,
    int count,
  ) async {
    var done = 0;
    while (done < count) {
      final read = await file.readInto(into, done, count);
      if (read <= 0) {
        throw const AttachmentCipherException('file ended early');
      }
      done += read;
    }
  }
}
