import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

/// The wire format of an encrypted chat file, `ababilx-att-v1`.
///
/// ```
/// key        32 random bytes, one per file, never reused
/// plaintext  the file, then zero bytes up to paddedSize(length)
/// chunk i    64 KiB of that (the last one shorter)
/// nonce i    4 zero bytes || u64 big-endian i
/// aad i      "ababilx-att-v1" || u32 big-endian i || 1 if last chunk else 0
/// output i   AES-256-GCM ciphertext || 16-byte tag
/// object     output 0 || output 1 || …
/// ```
///
/// The key is unique to the file, so a counter nonce can never repeat. The
/// chunk index in the AAD stops chunks being reordered; the last-chunk flag
/// stops the object being cut short at a chunk boundary, which would
/// otherwise decrypt cleanly into a shorter file.
///
/// **Every constant here is the format.** Web and desktop have to produce and
/// read the same bytes; `attachment_crypto_test.dart` pins them with a fixed
/// vector. Changing one makes every file already uploaded unopenable, with
/// nothing that names the cause.
abstract final class AttachmentCryptoFormat {
  static const algorithm = 'ababilx-att-v1';
  static const keyBytes = 32;
  static const chunkBytes = 64 * 1024;
  static const tagBytes = 16;
  static const nonceBytes = 12;

  /// Nothing smaller than this is uploaded, so a short note and a 400-byte
  /// file are the same size to the server.
  static const minPaddedBytes = 541;

  static final List<int> _label = utf8.encode(algorithm);

  /// The size a file of [plainBytes] is padded to before it is encrypted.
  ///
  /// Sizes fall into buckets 5% apart, so the server (and anyone watching the
  /// upload) learns a bucket rather than the exact length — exact lengths
  /// identify known files. The reader never recomputes this: it is told the
  /// real length inside the sealed meta and simply stops there, so a client
  /// may pad differently without breaking anyone.
  static int paddedSize(int plainBytes) {
    if (plainBytes <= minPaddedBytes) return minPaddedBytes;
    final steps = (math.log(plainBytes) / math.log(1.05)).ceil();
    final bucket = math.pow(1.05, steps).floor();
    // Floating point can land one bucket low right at a boundary.
    return math.max(bucket, plainBytes);
  }

  /// The encrypted object's length for a plaintext padded to [paddedBytes].
  static int cipherSizeForPadded(int paddedBytes) =>
      paddedBytes + chunkCount(paddedBytes) * tagBytes;

  /// The encrypted object's length for a file of [plainBytes].
  static int cipherSize(int plainBytes) =>
      cipherSizeForPadded(paddedSize(plainBytes));

  static int chunkCount(int paddedBytes) =>
      (paddedBytes + chunkBytes - 1) ~/ chunkBytes;

  static Uint8List chunkNonce(int index) {
    final nonce = Uint8List(nonceBytes);
    ByteData.sublistView(nonce).setUint64(4, index);
    return nonce;
  }

  static Uint8List chunkAad(int index, {required bool last}) {
    final aad = Uint8List(_label.length + 5);
    aad.setAll(0, _label);
    ByteData.sublistView(aad).setUint32(_label.length, index);
    aad[_label.length + 4] = last ? 1 : 0;
    return aad;
  }

  static Uint8List newKey() {
    final random = math.Random.secure();
    return Uint8List.fromList(
      List<int>.generate(keyBytes, (_) => random.nextInt(256)),
    );
  }
}

/// The object is not a well-formed `ababilx-att-v1` file: too short, cut off,
/// or shorter than the length its sender declared. A wrong key or a changed
/// byte surfaces as the cipher's own authentication error instead.
class AttachmentCipherException implements Exception {
  const AttachmentCipherException(this.message);

  final String message;

  @override
  String toString() => 'AttachmentCipherException: $message';
}
