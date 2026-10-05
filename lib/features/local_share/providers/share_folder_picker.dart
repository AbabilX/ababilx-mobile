import 'package:flutter/services.dart';

import '../local_share_actions.dart';

/// A folder the user picked, already copied where the app can read it.
class SharePickedFolder {
  const SharePickedFolder(this.name, this.picks);

  final String name;
  final List<SharePick> picks;
}

/// Picks a whole folder through Android's Storage Access Framework.
///
/// A folder path from a plain file picker cannot be listed on Android 11+
/// without all-files access, which this app does not ask for. The native side
/// walks the tree the user granted and copies each file into the app's cache,
/// reporting its path inside the folder.
abstract final class ShareFolderPicker {
  static const _channel = MethodChannel('com.ababilx.app/local_share_folder');

  static Future<bool> supported() async {
    try {
      return await _channel.invokeMethod<bool>('supported') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Null when the user backed out or the folder is empty.
  static Future<SharePickedFolder?> pick() async {
    try {
      final raw = await _channel.invokeMethod<Map<Object?, Object?>>('pick');
      final name = raw?['name'];
      final files = raw?['files'];
      if (name is! String || files is! List || files.isEmpty) return null;
      return SharePickedFolder(name, [
        for (final f in files)
          if (f is Map && f['path'] is String && f['relPath'] is String)
            SharePick(
              path: f['path'] as String,
              name: (f['relPath'] as String).split('/').last,
              mime: f['mime'] as String? ?? 'application/octet-stream',
              relPath: f['relPath'] as String,
              owned: true,
            ),
      ]);
    } catch (_) {
      return null;
    }
  }
}
