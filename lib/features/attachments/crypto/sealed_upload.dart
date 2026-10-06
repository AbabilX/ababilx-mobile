import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../../messages/data/models/chat_attachment.dart';
import 'attachment_crypto_format.dart';
import 'attachment_file_cipher.dart';
import 'attachment_secret.dart';

/// Encrypted uploads between their presign and their send.
///
/// An upload has three steps written in five places (composer, voice note,
/// camera, share sheet, khaam): presign, PUT, then a `ChatAttachmentInput`
/// built from the public URL. The key has to get from the first to the last
/// without every one of those call sites learning to carry it — a site that
/// forgot would upload a file in the clear, silently. So the key is filed
/// here under the upload's public URL at presign time, the PUT reads it to
/// encrypt, and `sendMessage` collects it into the attachment it sends.
///
/// Memory only: an upload that never became a message is useless after a
/// restart anyway, and once it has, the key lives in the send outbox.
abstract final class SealedUploads {
  static final _secrets = <String, AttachmentSecret>{};

  static void register(String fileUrl, AttachmentSecret secret) =>
      _secrets[fileUrl] = secret;

  static AttachmentSecret? secretFor(String fileUrl) => _secrets[fileUrl];

  /// The key filed for [fileUrl], with its sizes taken from the bytes that
  /// are actually about to go up. The presign only had the caller's figure,
  /// and a picker's figure can be off; the size sealed beside the key is
  /// where the reader stops, so a wrong one truncates the file or fails it.
  static AttachmentSecret? sizedFor(String fileUrl, int plainSize) {
    final secret = _secrets[fileUrl];
    if (secret == null || secret.plainSize == plainSize) return secret;
    return _secrets[fileUrl] = secret.withPlainSize(plainSize);
  }

  /// Dropped when the upload is discarded, and once its message is sent.
  static void forget(String fileUrl) => _secrets.remove(fileUrl);

  /// [attachments] with each encrypted upload's key attached. Anything that
  /// already carries one (a retry out of the outbox) is left as it is.
  ///
  /// The key stays filed until [forget]: a send that gave up before it
  /// reached the outbox is sent again from the caller's own list, which has
  /// no key in it — and without one that ciphertext would go out described
  /// as an ordinary file.
  static List<ChatAttachmentInput> attach(
    List<ChatAttachmentInput> attachments,
  ) {
    if (_secrets.isEmpty) return attachments;
    return [
      for (final a in attachments)
        if (a.secret == null && _secrets.containsKey(a.fileUrl))
          a.withSecret(_secrets[a.fileUrl]!)
        else
          a,
    ];
  }

  /// Encrypts [bytes] and PUTs the ciphertext. For what a picker already
  /// read into memory: a camera shot, a voice note, a shared file. The
  /// ciphertext is streamed out chunk by chunk, so the file is never held
  /// in memory twice.
  static Future<void> putBytes(
    String uploadUrl,
    List<int> bytes,
    AttachmentSecret secret, {
    ProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) => Dio().put<void>(
    uploadUrl,
    data: AttachmentFileCipher.sealStream(bytes, secret.key),
    options: Options(
      headers: {
        'Content-Type': SealedAttachmentWire.objectType,
        Headers.contentLengthHeader: AttachmentCryptoFormat.cipherSize(
          bytes.length,
        ),
      },
    ),
    cancelToken: cancelToken,
    onSendProgress: onProgress,
  );

  /// Encrypts [file] into a temporary file beside the cache and streams that
  /// up, so a large video is never held in memory. The ciphertext copy is
  /// deleted whether or not the upload succeeds.
  static Future<void> putFile(
    String uploadUrl,
    File file,
    AttachmentSecret secret, {
    ProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    final sealed = await _tempFile();
    try {
      final size = await AttachmentFileCipher.sealFile(
        file,
        sealed,
        secret.key,
        // A cancel while encrypting ends it the way a cancel while uploading
        // does: with Dio's own cancel error, which every caller already
        // treats as "not uploaded".
        checkpoint: () {
          final cancelled = cancelToken?.cancelError;
          if (cancelled != null) throw cancelled;
        },
      );
      await Dio().put<void>(
        uploadUrl,
        data: sealed.openRead(),
        options: Options(
          headers: {
            'Content-Type': SealedAttachmentWire.objectType,
            Headers.contentLengthHeader: size,
          },
        ),
        cancelToken: cancelToken,
        onSendProgress: onProgress,
      );
    } finally {
      try {
        if (await sealed.exists()) await sealed.delete();
      } catch (_) {}
    }
  }

  static Future<Directory>? _dir;
  static int _counter = 0;

  /// One directory, emptied the first time this process uploads: a kill
  /// mid-upload is the only way a ciphertext copy outlives its PUT, and
  /// nothing from an earlier process can still be in flight.
  static Future<File> _tempFile() async {
    final dir = await (_dir ??= _freshDir());
    return File('${dir.path}/${pid}_${_counter++}.bin');
  }

  static Future<Directory> _freshDir() async {
    final dir = Directory('${(await _cacheRoot()).path}/att-enc');
    try {
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {}
    return dir.create(recursive: true);
  }

  /// The app's cache directory; the Dart temp directory where there is no
  /// platform to ask (tests).
  static Future<Directory> _cacheRoot() async {
    try {
      return await getTemporaryDirectory();
    } catch (_) {
      return Directory.systemTemp;
    }
  }
}
