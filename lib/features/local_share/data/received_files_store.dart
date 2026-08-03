import 'dart:io';

import 'package:flutter/services.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Publishes a received file somewhere the user can actually find it:
/// `Download/AbabilXStorage` on Android (via a native MediaStore bridge —
/// visible in every file manager, no runtime permission needed on API 29+),
/// or `Documents/AbabilXStorage` on iOS (visible in the Files app thanks to
/// `UIFileSharingEnabled`).
class ReceivedFilesStore {
  ReceivedFilesStore._();

  static const folderName = 'AbabilXStorage';
  static const _channel = MethodChannel('com.ababilx.app/media_store');

  /// A private scratch path to stream incoming bytes into before publishing.
  static Future<String> reserveTempPath(String fileName) async {
    final tempDir = await getTemporaryDirectory();
    final unique = '${DateTime.now().microsecondsSinceEpoch}_$fileName';
    return p.join(tempDir.path, unique);
  }

  /// Moves the finished temp file into the public/visible location, handling
  /// filename collisions, and returns the final user-visible path.
  static Future<String> publish(String tempFilePath, String fileName) async {
    if (Platform.isAndroid) {
      final savedPath = await _channel.invokeMethod<String>('saveToDownloads', {
        'sourcePath': tempFilePath,
        'fileName': fileName,
        'subfolder': folderName,
        'mimeType': lookupMimeType(fileName),
      });
      if (savedPath == null) {
        throw StateError('Could not save $fileName to Downloads/$folderName');
      }
      return savedPath;
    }

    final docsDir = await getApplicationDocumentsDirectory();
    final destDir = Directory(p.join(docsDir.path, folderName));
    await destDir.create(recursive: true);
    final destPath = await _uniquePath(destDir.path, fileName);
    await File(tempFilePath).copy(destPath);
    await File(tempFilePath).delete();
    return destPath;
  }

  static Future<String> _uniquePath(String dir, String fileName) async {
    final ext = p.extension(fileName);
    final base = p.basenameWithoutExtension(fileName);
    var candidate = p.join(dir, fileName);
    var i = 1;
    while (await File(candidate).exists()) {
      candidate = p.join(dir, '$base ($i)$ext');
      i++;
    }
    return candidate;
  }
}
