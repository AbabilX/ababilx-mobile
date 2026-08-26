import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:mime/mime.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../features/local_share/data/received_files_store.dart';

/// One file the user asked to keep.
class SaveToPhoneRequest {
  const SaveToPhoneRequest({
    required this.sourcePath,
    required this.fileName,
    this.contentType = '',
  });

  final String sourcePath;
  final String fileName;
  final String contentType;
}

enum SaveToPhoneStatus { saved, sourceMissing, failed }

class SaveToPhoneResult {
  const SaveToPhoneResult(this.status, [this.savedPath]);

  final SaveToPhoneStatus status;
  final String? savedPath;

  bool get ok => status == SaveToPhoneStatus.saved;
}

const _channel = MethodChannel('com.ababilx.app/media_store');

/// Which public MediaStore collection a file belongs in.
///
/// Photos and video must land in Pictures/Movies or the gallery never indexes
/// them; everything else goes to Downloads, where a file manager finds it.
String mediaStoreCollectionFor(String mimeType) {
  if (mimeType.startsWith('image/')) return 'images';
  if (mimeType.startsWith('video/')) return 'video';
  return 'downloads';
}

/// Strips path separators and the characters MediaStore rejects.
String safeSaveFileName(String fileName, {String fallback = 'file'}) {
  final trimmed = fileName.trim();
  if (trimmed.isEmpty) return fallback;
  return trimmed.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
}

/// Copies a file the app already holds into the user's own storage.
///
/// A copy, never a move: the app-private original is what every renderer
/// reads, and on API 29+ the path returned here cannot be read back.
///
/// Storage permission is asked for only after a failure, never up front. The
/// manifest caps WRITE_EXTERNAL_STORAGE at API 28, so on every current handset
/// the MediaStore write needs no permission at all — prompting first would put
/// a dialog in front of the common path that Android 13+ auto-denies anyway.
Future<SaveToPhoneResult> saveFileToPhone(SaveToPhoneRequest request) async {
  if (request.sourcePath.isEmpty || !File(request.sourcePath).existsSync()) {
    return const SaveToPhoneResult(SaveToPhoneStatus.sourceMissing);
  }
  final first = await _attempt(request);
  if (first.ok || !Platform.isAndroid) return first;
  if (!await _grantLegacyStorage()) return first;
  return _attempt(request);
}

Future<SaveToPhoneResult> _attempt(SaveToPhoneRequest request) async {
  final name = safeSaveFileName(request.fileName);
  final mime = request.contentType.isNotEmpty
      ? request.contentType
      : (lookupMimeType(name) ?? 'application/octet-stream');
  try {
    final saved = Platform.isAndroid
        ? await _channel.invokeMethod<String>('saveToDownloads', {
            'sourcePath': request.sourcePath,
            'fileName': name,
            'subfolder': ReceivedFilesStore.folderName,
            'mimeType': mime,
            'collection': mediaStoreCollectionFor(mime),
            'deleteSource': false,
          })
        : await ReceivedFilesStore.publishCopy(request.sourcePath, name);
    if (saved == null || saved.isEmpty) {
      return const SaveToPhoneResult(SaveToPhoneStatus.failed);
    }
    return SaveToPhoneResult(SaveToPhoneStatus.saved, saved);
  } catch (_) {
    return const SaveToPhoneResult(SaveToPhoneStatus.failed);
  }
}

Future<bool> _grantLegacyStorage() async {
  try {
    if (await Permission.storage.isGranted) return false;
    return (await Permission.storage.request()).isGranted;
  } catch (_) {
    return false;
  }
}

/// Where a saved file ends up, for the confirmation line.
String get saveToPhoneFolderLabel => Platform.isAndroid
    ? 'Downloads/${ReceivedFilesStore.folderName}'
    : 'Files › ${ReceivedFilesStore.folderName}';

/// Pulls a remote object into a scratch file so it can be saved or shared.
///
/// Only for surfaces that already render straight from the URL — the wall and
/// CRM previews. Chat attachments must never come through here: their bytes
/// reach disk through [AttachmentDownloader], which is where the decryption
/// seam lives, and fetching the object raw would write ciphertext the day that
/// seam stops being a passthrough.
Future<String?> fetchToTempFile(String url, String fileName) async {
  if (url.isEmpty) return null;
  try {
    final path = await ReceivedFilesStore.reserveTempPath(
      safeSaveFileName(fileName),
    );
    await Dio().download(
      url,
      path,
      options: Options(
        followRedirects: true,
        validateStatus: (s) => s != null && s >= 200 && s < 400,
      ),
    );
    return File(path).existsSync() ? path : null;
  } catch (_) {
    return null;
  }
}
