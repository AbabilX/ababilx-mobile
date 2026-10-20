import 'dart:io';
import 'dart:typed_data';

import '../data/local/attachment_blob_store.dart';
import '../data/local/attachment_dedupe_store.dart';
import '../data/models/attachment_handle.dart';
import '../data/models/attachment_url_key.dart';
import 'attachment_content_dedupe.dart';
import 'attachment_content_hash.dart';
import 'attachment_dimension_reader.dart';
import 'attachment_paths.dart';
import 'attachment_queue.dart';

/// The conversation a fresh upload belongs to, read off its URL: the server
/// names every new object `chat/<conversation id>/<uuid>.<ext>`. Null for
/// anything else (a pre-0145 `teams/…` object, a foreign URL).
String? uploadConversationId(String fileUrl) =>
    _conversationInUrl.firstMatch(fileUrl)?.group(1);

final _conversationInUrl = RegExp(r'/chat/([0-9a-fA-F-]{36})/');

/// Files the sender already has, filed under the URL they were uploaded to.
///
/// Without this the composer uploads a photo, the message comes back, and the
/// gate finds no local copy — so the person who *just picked the image* is
/// shown a download button for their own file, and (on a metered plan) pays to
/// fetch back the bytes still sitting in their gallery.
///
/// Signal does the same thing from the other end: an outgoing attachment is
/// written into the attachment store at compose time and its transfer state is
/// `DONE` before the message row is ever inserted. Nothing outgoing is ever
/// downloaded.
class AttachmentAdopter {
  AttachmentAdopter(
    this._blobs,
    this._dedupe,
    this._paths,
    this._queue, {
    this._dimensions,
    this._isLocked,
  });

  /// A locked chat keeps its files in memory only (chat lock). Every
  /// adoption follows a fresh upload, and a fresh upload's object key is
  /// `chat/<conversation id>/…` (server `AttachmentPrefix`), so the URL alone
  /// says which chat it belongs to — one check here covers the composer,
  /// voice notes, the camera and share intake.
  final bool Function(String conversationId)? _isLocked;

  bool _lockedUpload(String fileUrl) {
    final check = _isLocked;
    if (check == null) return false;
    final id = uploadConversationId(fileUrl);
    return id != null && check(id);
  }

  final AttachmentBlobStore _blobs;
  final AttachmentDedupeStore _dedupe;
  final AttachmentPaths _paths;
  final AttachmentQueue _queue;
  final AttachmentDimensionReader? _dimensions;

  /// Whether this phone already holds [fileUrl]'s bytes. Lets a restore skip
  /// a file it would only copy and then drop as already present.
  Future<bool> holds(String fileUrl) async {
    final urlKey = attachmentUrlKey(fileUrl);
    if (urlKey.isEmpty) return false;
    try {
      return await _blobs.isReady(urlKey);
    } catch (_) {
      return false;
    }
  }

  /// A file the picker gave us a real path to (gallery item, camera capture).
  Future<void> adoptFile({
    required String fileUrl,
    required String fileName,
    required String contentType,
    required File source,
  }) async {
    if (!await source.exists()) return;
    await _commit(
      fileUrl: fileUrl,
      fileName: fileName,
      contentType: contentType,
      write: (target) => source.copy(target.path),
    );
  }

  /// Bytes with no path worth keeping — SAF documents, camera shots handed
  /// back in memory, anything the composer re-encoded.
  Future<void> adoptBytes({
    required String fileUrl,
    required String fileName,
    required String contentType,
    required Uint8List bytes,
  }) async {
    if (bytes.isEmpty) return;
    await _commit(
      fileUrl: fileUrl,
      fileName: fileName,
      contentType: contentType,
      write: (target) => target.writeAsBytes(bytes, flush: true),
    );
  }

  Future<void> _commit({
    required String fileUrl,
    required String fileName,
    required String contentType,
    required Future<File> Function(File target) write,
  }) async {
    final urlKey = attachmentUrlKey(fileUrl);
    if (urlKey.isEmpty || _lockedUpload(fileUrl)) return;
    try {
      // Already on disk under this key — a retry of the same send, or the
      // object came back from a dedupe hit. Nothing to do.
      if (await _blobs.isReady(urlKey)) return;

      final target = await _paths.fileFor(urlKey, fileName, contentType);
      final stored = await write(target);
      final bytes = await stored.length();
      final hash = await hashFileContents(stored);
      final resolution = await resolveDedupedStoragePath(
        _dedupe,
        urlKey,
        hash,
        stored,
      );

      // Same ordering rule as a finished download: the row commits first, so a
      // crash in between leaves an orphan file the sweeper reclaims rather
      // than a row pointing at bytes that are gone.
      await _blobs.ensure(
        urlKey: urlKey,
        remoteUrl: fileUrl,
        fileName: fileName,
        contentType: contentType,
        expectedBytes: bytes,
      );
      await _blobs.markReady(urlKey, resolution.path, bytes, contentHash: hash);
      final redundant = resolution.redundantFile;
      if (redundant != null) {
        try {
          await redundant.delete();
        } catch (_) {}
      }

      // Any gate already on screen for this object flips without a re-resolve,
      // and the confirmed bubble mounts at the photo's real height.
      final ready = AttachmentHandle(
        urlKey: urlKey,
        remoteUrl: fileUrl,
        state: AttachmentTransferState.ready,
        fileName: fileName,
        contentType: contentType,
        localPath: resolution.path,
        receivedBytes: bytes,
        totalBytes: bytes,
      );
      _queue.announce(await _dimensions?.complete(ready) ?? ready);
    } catch (_) {
      // Adoption is an optimisation. A failure here costs one download later,
      // never the send.
    }
  }
}
