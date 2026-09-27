import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// The layout of a local backup file:
///
/// ```
/// magic    8 bytes  "ABXBAK" 0x00 0x01
/// header   u32 big-endian length + UTF-8 JSON, in the clear
/// records  u32 big-endian length + nonce | ciphertext | tag, until END
/// ```
///
/// A record's plaintext is one type byte and a body ([BackupRecordType]). The
/// header is clear so a restore can say whose file this is and when it was
/// written before it asks for a key; it holds no content, only the account id,
/// the salt and the account check. Every record's AAD carries the header's
/// digest, so an edited header fails the first record instead of being
/// believed.
abstract final class BackupFormat {
  static const magic = [0x41, 0x42, 0x58, 0x42, 0x41, 0x4B, 0x00, 0x01];
  static const version = 1;
  static const extension = '.abxbackup';

  /// A record is refused past this, so a corrupt length cannot make a reader
  /// allocate the whole file.
  static const maxRecordBytes = 4 * 1024 * 1024;
  static const maxHeaderBytes = 64 * 1024;
}

abstract final class BackupRecordType {
  /// gzip of newline-delimited JSON frames.
  static const frames = 1;

  /// Raw bytes of the file named by the last `file` frame before it.
  static const filePart = 2;

  /// JSON `{frames, files}`. Load-bearing like the archive's end frame: a
  /// file cut short is refused as incomplete, never read as a shorter history.
  static const end = 0x7F;
}

class BackupHeader {
  const BackupHeader({
    required this.userId,
    required this.salt,
    required this.keyCheck,
    required this.createdAtMs,
    this.version = BackupFormat.version,
  });

  final int version;
  final String userId;
  final List<int> salt;
  final List<int> keyCheck;
  final int createdAtMs;

  Map<String, dynamic> toJson() => {
    'v': version,
    'user_id': userId,
    'salt': base64Url.encode(salt),
    'key_check': base64Url.encode(keyCheck),
    'created_at_ms': createdAtMs,
  };

  /// Returns null for anything that is not a header this app can read.
  static BackupHeader? fromJson(Object? json) {
    if (json is! Map) return null;
    try {
      final version = (json['v'] as num).toInt();
      if (version < 1 || version > BackupFormat.version) return null;
      return BackupHeader(
        version: version,
        userId: json['user_id'] as String,
        salt: base64Url.decode(json['salt'] as String),
        keyCheck: base64Url.decode(json['key_check'] as String),
        createdAtMs: (json['created_at_ms'] as num).toInt(),
      );
    } catch (_) {
      return null;
    }
  }
}

/// The header bytes exactly as written, and the digest records bind to.
class EncodedHeader {
  EncodedHeader(this.bytes) : digest = sha256.convert(bytes).toString();

  factory EncodedHeader.of(BackupHeader header) => EncodedHeader(
    Uint8List.fromList(utf8.encode(jsonEncode(header.toJson()))),
  );

  final Uint8List bytes;
  final String digest;
}

Uint8List u32(int value) =>
    Uint8List(4)..buffer.asByteData().setUint32(0, value, Endian.big);

int readU32(List<int> bytes) =>
    ByteData.sublistView(Uint8List.fromList(bytes)).getUint32(0, Endian.big);
