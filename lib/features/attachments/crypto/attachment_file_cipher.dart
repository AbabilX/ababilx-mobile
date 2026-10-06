import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'attachment_chunk_cipher.dart';
import 'attachment_crypto_format.dart';

/// Encrypts and decrypts chat files in the [AttachmentCryptoFormat] layout.
///
/// A file goes through one chunk at a time, so a 350 MB video never sits in
/// memory — and every write is awaited, so a fast cipher cannot queue the
/// whole file in front of a slow disk either. The in-memory pair exists for
/// what is deliberately never written to disk: a timed photo, a locked chat's
/// media, the picture on a notification.
abstract final class AttachmentFileCipher {
  static const _chunk = AttachmentCryptoFormat.chunkBytes;
  static const _tag = AttachmentCryptoFormat.tagBytes;

  /// Encrypts [source] into [target] under [key]. Returns the object's length.
  ///
  /// [checkpoint] runs before every chunk and may throw to stop: a large
  /// video takes seconds, and a cancelled upload should not finish
  /// encrypting first.
  static Future<int> sealFile(
    File source,
    File target,
    List<int> key, {
    void Function()? checkpoint,
  }) async {
    final plainSize = await source.length();
    final padded = AttachmentCryptoFormat.paddedSize(plainSize);
    final secret = SecretKey(key);
    final input = await source.open();
    final output = await target.open(mode: FileMode.writeOnly);
    try {
      var offset = 0;
      for (var index = 0; offset < padded; index++) {
        checkpoint?.call();
        final length = math.min(_chunk, padded - offset);
        // Zero-filled, so whatever the file does not cover is the padding.
        final chunk = Uint8List(length);
        if (offset < plainSize) {
          await AttachmentChunkCipher.readFully(
            input,
            chunk,
            math.min(length, plainSize - offset),
          );
        }
        offset += length;
        final box = await AttachmentChunkCipher.seal(
          secret,
          chunk,
          index,
          last: offset >= padded,
        );
        await output.writeFrom(box.cipherText);
        await output.writeFrom(box.mac.bytes);
      }
    } finally {
      await input.close();
      await output.close();
    }
    return AttachmentCryptoFormat.cipherSizeForPadded(padded);
  }

  /// Decrypts [cipher] into [target], dropping the padding after
  /// [plainSize]. Throws rather than leave a partly written [target] behind.
  static Future<void> openFile(
    File cipher,
    File target,
    List<int> key,
    int plainSize,
  ) async {
    final total = await cipher.length();
    AttachmentChunkCipher.checkStatedSize(plainSize, total);
    final secret = SecretKey(key);
    final input = await cipher.open();
    final output = await target.open(mode: FileMode.writeOnly);
    var written = 0;
    var failed = true;
    try {
      var offset = 0;
      for (var index = 0; offset < total; index++) {
        final length = math.min(_chunk + _tag, total - offset);
        if (length <= _tag) {
          throw const AttachmentCipherException('object ends mid-chunk');
        }
        final sealed = Uint8List(length);
        await AttachmentChunkCipher.readFully(input, sealed, length);
        offset += length;
        final clear = await AttachmentChunkCipher.open(
          secret,
          sealed,
          index,
          last: offset >= total,
        );
        final keep = math.min(clear.length, plainSize - written);
        if (keep > 0) await output.writeFrom(clear, 0, keep);
        written += math.max(keep, 0);
      }
      if (written != plainSize) {
        throw const AttachmentCipherException('object is shorter than stated');
      }
      failed = false;
    } finally {
      await input.close();
      await output.close();
      if (failed) {
        try {
          await target.delete();
        } catch (_) {}
      }
    }
  }

  /// The ciphertext of [plain], one chunk at a time, for an upload that
  /// already holds the file in memory: streamed out, it never holds a second
  /// copy. Its total length is [AttachmentCryptoFormat.cipherSize].
  static Stream<List<int>> sealStream(List<int> plain, List<int> key) async* {
    final padded = AttachmentCryptoFormat.paddedSize(plain.length);
    final secret = SecretKey(key);
    var offset = 0;
    for (var index = 0; offset < padded; index++) {
      final length = math.min(_chunk, padded - offset);
      final chunk = Uint8List(length);
      if (offset < plain.length) {
        final end = math.min(offset + length, plain.length);
        chunk.setRange(0, end - offset, plain, offset);
      }
      offset += length;
      final box = await AttachmentChunkCipher.seal(
        secret,
        chunk,
        index,
        last: offset >= padded,
      );
      yield box.cipherText;
      yield box.mac.bytes;
    }
  }

  static Future<Uint8List> sealBytes(List<int> plain, List<int> key) async {
    final out = Uint8List(AttachmentCryptoFormat.cipherSize(plain.length));
    var at = 0;
    await for (final part in sealStream(plain, key)) {
      out.setRange(at, at + part.length, part);
      at += part.length;
    }
    return out;
  }

  static Future<Uint8List> openBytes(
    List<int> cipher,
    List<int> key,
    int plainSize,
  ) async {
    final all = cipher is Uint8List ? cipher : Uint8List.fromList(cipher);
    AttachmentChunkCipher.checkStatedSize(plainSize, all.length);
    final secret = SecretKey(key);
    final out = Uint8List(plainSize);
    var written = 0;
    var offset = 0;
    for (var index = 0; offset < all.length; index++) {
      final length = math.min(_chunk + _tag, all.length - offset);
      if (length <= _tag) {
        throw const AttachmentCipherException('object ends mid-chunk');
      }
      final sealed = Uint8List.sublistView(all, offset, offset + length);
      offset += length;
      final clear = await AttachmentChunkCipher.open(
        secret,
        sealed,
        index,
        last: offset >= all.length,
      );
      final keep = math.min(clear.length, plainSize - written);
      if (keep > 0) out.setRange(written, written + keep, clear);
      written += math.max(keep, 0);
    }
    if (written != plainSize) {
      throw const AttachmentCipherException('object is shorter than stated');
    }
    return out;
  }
}
