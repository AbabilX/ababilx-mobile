import 'dart:io';

import '../../../shared/avatar-store/avatar_index.dart';
import '../../calls/data/models/call_log_entry.dart';
import '../format/backup_file_writer.dart';
import 'backup_prefs.dart';

class BackupExtrasStats {
  const BackupExtrasStats({
    required this.calls,
    required this.settings,
    required this.pictures,
  });
  final int calls;
  final int settings;
  final int pictures;
}

/// What Signal's backup carries beside messages: the call log, settings,
/// and the pictures that make the list recognisable (profile and group
/// photos, wallpaper photos). Written before the messages, so a restore cut
/// short still has them.
///
/// Extra files carry `x` (their kind) and no `u`: an older build's importer
/// adopts a `file` frame by its `u`, and skips one without, so a new backup
/// never plants an avatar in an old phone's attachment store.
Future<BackupExtrasStats> writeBackupExtras(
  BackupFileWriter writer, {
  required List<CallLogEntry> calls,
  required Directory? wallpaperDir,
  required Directory? avatarDir,
  required Map<String, AvatarEntry> avatars,
}) async {
  await writer.addFrame({'t': 'env', 'wp': wallpaperDir?.path ?? ''});
  for (final call in calls) {
    await writer.addFrame({'t': 'call', 'c': call.toJson()});
  }
  final prefs = await BackupPrefs.export();
  for (final frame in prefs) {
    await writer.addFrame(frame);
  }
  var pictures = 0;
  if (wallpaperDir != null && await wallpaperDir.exists()) {
    await for (final item in wallpaperDir.list()) {
      if (item is! File) continue;
      final name = item.uri.pathSegments.last;
      if (await writer.addFile({'x': 'wallpaper', 'n': name}, item)) {
        pictures++;
      }
    }
  }
  if (avatarDir != null) {
    // One copy per file, with every key that points at it.
    final byFile = <String, Map<String, dynamic>>{};
    for (final e in avatars.entries) {
      (byFile[e.value.file] ??= {})[e.key] = e.value.toJson();
    }
    for (final e in byFile.entries) {
      final file = File('${avatarDir.path}/${e.key}');
      if (!await file.exists()) continue;
      if (await writer.addFile({
        'x': 'avatar',
        'f': e.key,
        'e': e.value,
      }, file)) {
        pictures++;
      }
    }
  }
  return BackupExtrasStats(
    calls: calls.length,
    settings: prefs.length,
    pictures: pictures,
  );
}
