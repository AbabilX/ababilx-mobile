import 'dart:convert';

import 'attachment_crypto_format.dart';

/// What the server is told about an encrypted file: its kind and nothing
/// else. Twins of the server's `SealedAttachmentContentType` /
/// `SealedAttachmentName` (services/chat/attachment_seal.go), which normalizes
/// to the same values whatever a client sends.
abstract final class SealedAttachmentWire {
  static const objectType = 'application/octet-stream';
  static const fileName = 'file';
  static const voiceName = 'voice-message';

  static final _image = RegExp(
    r'\.(jpe?g|png|gif|webp|bmp|heic|heif|avif|svg)$',
    caseSensitive: false,
  );
  static final _video = RegExp(
    r'\.(mp4|m4v|mov|webm|mkv|avi|3gp)$',
    caseSensitive: false,
  );
  static final _audio = RegExp(
    r'\.(m4a|aac|mp3|ogg|opus|wav)$',
    caseSensitive: false,
  );

  /// `image/…`, `video/…`, `audio/…` or a plain file. Decided from the name
  /// as well as the type, because pickers hand over `application/octet-stream`
  /// for plenty of photos.
  static String type(String contentType, String name) {
    final ct = contentType.toLowerCase();
    for (final kind in const ['image', 'video', 'audio']) {
      if (ct.startsWith('$kind/')) return '$kind/x-ababilx-sealed';
    }
    if (_image.hasMatch(name)) return 'image/x-ababilx-sealed';
    if (_video.hasMatch(name)) return 'video/x-ababilx-sealed';
    if (_audio.hasMatch(name)) return 'audio/x-ababilx-sealed';
    return objectType;
  }

  /// A voice note keeps the recorder's prefix: the server's group media
  /// permissions and the push label both recognise one by it.
  static String name(String contentType, String name) {
    final voice =
        type(contentType, name).startsWith('audio/') &&
        name.split('/').last.toLowerCase().startsWith('voice-');
    return voice ? voiceName : fileName;
  }
}

/// The key of one encrypted file, with what this device needs beside it.
///
/// Never sent anywhere as it is. On the way out it is sealed under the
/// conversation key (`MessageVault.sealAttachments`); on this device it is
/// held in memory, and written only into the local send outbox so a send
/// interrupted by a kill can still be finished.
class AttachmentSecret {
  const AttachmentSecret({
    required this.key,
    required this.plainSize,
    required this.cipherSize,
    required this.wireName,
    required this.wireType,
  });

  final List<int> key;

  /// The file's real length; the object is padded past it.
  final int plainSize;

  /// The encrypted object's length, which is what the server stores as the
  /// attachment's size.
  final int cipherSize;

  /// The public description the server keeps (`file`, `image/x-ababilx-sealed`).
  /// Carried so an opened attachment can be written back to disk exactly as it
  /// was served, sealed, without the real name beside it.
  final String wireName;
  final String wireType;

  /// A fresh key for a file about to be uploaded.
  factory AttachmentSecret.forUpload({
    required String fileName,
    required String contentType,
    required int plainSize,
  }) => AttachmentSecret(
    key: AttachmentCryptoFormat.newKey(),
    plainSize: plainSize,
    cipherSize: AttachmentCryptoFormat.cipherSize(plainSize),
    wireName: SealedAttachmentWire.name(contentType, fileName),
    wireType: SealedAttachmentWire.type(contentType, fileName),
  );

  /// This key for a file that is really [plainSize] bytes long.
  AttachmentSecret withPlainSize(int plainSize) => AttachmentSecret(
    key: key,
    plainSize: plainSize,
    cipherSize: AttachmentCryptoFormat.cipherSize(plainSize),
    wireName: wireName,
    wireType: wireType,
  );

  factory AttachmentSecret.fromJson(Map<String, dynamic> json) =>
      AttachmentSecret(
        key: base64Url.decode(base64Url.normalize(json['k'] as String? ?? '')),
        plainSize: (json['s'] as num?)?.toInt() ?? 0,
        cipherSize: (json['c'] as num?)?.toInt() ?? 0,
        wireName: json['wn'] as String? ?? SealedAttachmentWire.fileName,
        wireType: json['wt'] as String? ?? SealedAttachmentWire.objectType,
      );

  /// Local storage only — see the class note.
  Map<String, dynamic> toJson() => {
    'k': base64Url.encode(key).replaceAll('=', ''),
    's': plainSize,
    'c': cipherSize,
    'wn': wireName,
    'wt': wireType,
  };
}

/// The AAD a sealed meta is authenticated with: the conversation, the
/// conversation key version it is sealed under, and whoever sealed it (the
/// message's sender). The prefix differs from a message body's, so a sealed
/// meta can never be replayed as a message, and naming the conversation and
/// the sender means it cannot be moved to another of either.
///
/// Part of the wire format — byte-identical on every client.
List<int> attachmentSealAad(
  String conversationId,
  int keyVersion,
  String sealerId,
) => utf8.encode('ababilx-att-meta-v1:$conversationId:$keyVersion:$sealerId');

/// One attachment's sealed meta as it crosses the API: the ciphertext of
/// [AttachmentSealPayload] under the conversation key, and that seal's nonce.
class SealedAttachmentMeta {
  const SealedAttachmentMeta({required this.encMeta, required this.encNonce});

  final String encMeta;
  final String encNonce;
}

/// The plaintext inside a sealed meta. Part of the wire format, pinned by
/// `attachment_seal_test.dart`:
///
/// ```json
/// {"v":1,"k":"<base64url key>","n":"IMG_0012.jpg","t":"image/jpeg","s":123456}
/// ```
class AttachmentSealPayload {
  const AttachmentSealPayload({
    required this.key,
    required this.fileName,
    required this.contentType,
    required this.plainSize,
  });

  static const version = 1;

  final List<int> key;
  final String fileName;
  final String contentType;
  final int plainSize;

  List<int> encode() => utf8.encode(
    jsonEncode({
      'v': version,
      'k': base64Url.encode(key).replaceAll('=', ''),
      'n': fileName,
      't': contentType,
      's': plainSize,
    }),
  );

  /// Throws [FormatException] for anything that is not a usable v1 payload —
  /// a wrong key length most of all, since the cipher would reject it later
  /// with an error that names nothing.
  factory AttachmentSealPayload.decode(List<int> bytes) {
    final json = jsonDecode(utf8.decode(bytes));
    if (json is! Map || json['v'] != version) {
      throw const FormatException('unknown attachment seal version');
    }
    final key = base64Url.decode(base64Url.normalize(json['k'] as String));
    final size = (json['s'] as num?)?.toInt() ?? -1;
    if (key.length != AttachmentCryptoFormat.keyBytes || size < 0) {
      throw const FormatException('malformed attachment seal');
    }
    return AttachmentSealPayload(
      key: key,
      fileName: json['n'] as String? ?? '',
      contentType: json['t'] as String? ?? '',
      plainSize: size,
    );
  }
}
