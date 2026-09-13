import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../../../shared/media/device_gallery.dart';
import '../../../shared/media/native_media_send.dart';
import '../../../shared/media/picked_media_file.dart';

const int maxChatAttachmentBytes = 350 * 1024 * 1024;

class ChatAttachmentSizeException implements Exception {
  const ChatAttachmentSizeException(this.sizeBytes);

  final int sizeBytes;
}

void validateChatAttachmentSize(int sizeBytes) {
  if (sizeBytes <= 0 || sizeBytes > maxChatAttachmentBytes) {
    throw ChatAttachmentSizeException(sizeBytes);
  }
}

/// One file to be attached, described without its bytes.
///
/// The split matters. A presign needs only the name, the type and the length,
/// so the composer can show a tile and reserve a URL for every picked photo
/// before a single byte is read — and the bytes themselves are then read one
/// upload at a time, instead of an album sitting in the Dart heap at once. Ten
/// photos on High are 30 MB that way; ten videos, which are never transcoded,
/// would be far worse.
class UploadSource {
  const UploadSource({
    required this.fileName,
    required this.contentType,
    required this.sizeBytes,
    this.localPath,
    this.bytes,
  });

  final String fileName;
  final String contentType;
  final int sizeBytes;

  /// A real path we can keep, when there is one. Camera shots and documents
  /// picked through SAF arrive as bytes with no durable path.
  final String? localPath;

  /// Bytes a picker already read for us. Set only when [localPath] is null.
  final Uint8List? bytes;

  Future<Uint8List?> read() async {
    final held = bytes;
    if (held != null) return held;
    final path = localPath;
    if (path == null) return null;
    final file = File(path);
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }
}

/// Resolves one pick to a description — a disk copy at worst, never a read
/// into memory. Returns null for a file that has gone.
typedef UploadSourceLoader = Future<UploadSource?> Function();

/// Documents stay on disk so a 350 MB attachment never occupies the Dart
/// heap in one allocation. Mobile FilePicker supplies a temporary local path.
UploadSourceLoader deviceFileSource() => () async {
  final result = await FilePicker.platform.pickFiles(
    allowMultiple: false,
    withData: false,
  );
  if (result == null || result.files.isEmpty) return null;
  final picked = result.files.first;
  final path = picked.path;
  if (path == null || path.isEmpty) return null;
  final file = File(path);
  if (!await file.exists()) return null;
  return UploadSource(
    fileName: picked.name,
    contentType: contentTypeForFileName(picked.name),
    sizeBytes: await file.length(),
    localPath: path,
  );
};

/// A library item: copied out of MediaStore first, because a `content://`
/// grant does not outlive the panel that handed it over.
UploadSourceLoader libraryItemSource(DeviceMediaItem item) => () async {
  final file = await DeviceGallery.materialize(item);
  if (file == null) return null;
  return UploadSource(
    fileName: item.name,
    contentType: item.mime,
    sizeBytes: await file.length(),
    localPath: file.path,
  );
};

/// The native flow already wrote a real file, edits flattened in.
UploadSourceLoader nativeFileSource(NativeMediaFile file) => () async {
  final source = File(file.path);
  if (!await source.exists()) return null;
  return UploadSource(
    fileName: file.fileName,
    contentType: file.contentType,
    sizeBytes: await source.length(),
    localPath: file.path,
  );
};

/// A camera shot or a document the Dart pickers already read.
UploadSourceLoader pickedFileSource(PickedMediaFile picked) =>
    () async => UploadSource(
      fileName: picked.fileName,
      contentType: picked.contentType,
      sizeBytes: picked.sizeBytes,
      bytes: picked.bytes,
    );
