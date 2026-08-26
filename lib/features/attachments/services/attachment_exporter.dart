import 'dart:io';

import 'package:flutter/services.dart';

import '../../../shared/media/save_to_phone.dart';
import '../../local_share/data/received_files_store.dart';
import '../data/local/attachment_blob_store.dart';
import '../data/models/attachment_handle.dart';

/// Publishes a user-visible copy of a finished download.
///
/// The canonical bytes stay in the app-private sandbox — that is what playback
/// reads, and the only thing that survives scoped storage and a future
/// encrypted-at-rest layer. This copy exists so the files also turn up where a
/// WhatsApp user expects them: the gallery for photos and video, the Downloads
/// folder for everything else.
///
/// A copy, never a move: the native bridge is told `deleteSource: false`.
/// Every failure here is swallowed — a file the user cannot find in their
/// gallery is a nuisance, a file the app cannot play is a bug.
class AttachmentExporter {
  AttachmentExporter(this._blobs);

  final AttachmentBlobStore _blobs;

  static const _channel = MethodChannel('com.ababilx.app/media_store');

  Future<void> export(AttachmentHandle handle) async {
    final path = handle.localPath;
    if (path == null || path.isEmpty) return;
    final row = await _blobs.read(handle.urlKey);
    if (row == null || row.exportedAtMs != null) return;
    if (!File(path).existsSync()) return;

    try {
      final saved = Platform.isAndroid
          ? await _exportAndroid(path, handle)
          : await ReceivedFilesStore.publishCopy(path, _safeName(handle));
      if (saved != null && saved.isNotEmpty) {
        await _blobs.markExported(handle.urlKey, saved);
      }
    } catch (_) {
      // Left unexported; the next successful download of another file will
      // try again for that one. Nothing retries this, by design.
    }
  }

  Future<String?> _exportAndroid(String path, AttachmentHandle handle) {
    return _channel.invokeMethod<String>('saveToDownloads', {
      'sourcePath': path,
      'fileName': _safeName(handle),
      'subfolder': ReceivedFilesStore.folderName,
      'mimeType': handle.contentType.isNotEmpty
          ? handle.contentType
          : 'application/octet-stream',
      'collection': _collection(handle.contentType),
      // The private copy is the one every renderer reads. Moving it here
      // would leave the app with a path it cannot even open back on API 29+.
      'deleteSource': false,
    });
  }

  // Collection and name rules are shared with the explicit "Save to phone"
  // action — two copies of "which MediaStore bucket is this" is how a photo
  // ends up saved into Downloads and never indexed by the gallery.
  String _collection(String contentType) =>
      mediaStoreCollectionFor(contentType);

  String _safeName(AttachmentHandle handle) =>
      safeSaveFileName(handle.fileName, fallback: handle.urlKey);
}
