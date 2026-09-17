import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../protocol/ghost_frames.dart';

/// The one place Ghost Chat bytes ever touch the disk, and why.
///
/// A PDF or a video cannot be handed to another app from memory — Android
/// opens a file, not a buffer. So opening one writes it under the app's
/// private cache, in a folder this class owns, and that folder is deleted on
/// every burn and again at every app start, which catches a process killed
/// mid-session. Photos never come here: they draw straight from memory.
abstract final class GhostTempFiles {
  static Future<Directory> _root() async {
    final cache = await getTemporaryDirectory();
    return Directory('${cache.path}/ghost');
  }

  /// Writes [bytes] for opening and returns the path.
  static Future<String> writeForOpen(String name, Uint8List bytes) async {
    final dir = Directory(
      '${(await _root()).path}/${DateTime.now().microsecondsSinceEpoch}',
    );
    await dir.create(recursive: true);
    final file = File('${dir.path}/${safeGhostFileName(name)}');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  /// Overwrites, then deletes, everything under the ghost folder.
  static Future<void> purge() async {
    try {
      final root = await _root();
      if (!await root.exists()) return;
      await for (final entity in root.list(recursive: true)) {
        if (entity is File) {
          try {
            final length = await entity.length();
            await entity.writeAsBytes(Uint8List(length), flush: true);
          } catch (_) {}
        }
      }
      await root.delete(recursive: true);
    } catch (_) {
      // Nothing to do if the cache is already gone.
    }
  }

  /// A picker copies the chosen file into this app's cache before handing it
  /// over. That copy is ours to remove — the user's original never is, so only
  /// a path inside our own cache directory is ever deleted.
  static Future<void> deletePickerCopy(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      final cache = (await getTemporaryDirectory()).path;
      final absolute = File(path).absolute.path;
      if (absolute.split('/').contains('..') ||
          !absolute.startsWith('$cache/')) {
        return;
      }
      await File(path).delete();
    } catch (_) {}
  }
}
