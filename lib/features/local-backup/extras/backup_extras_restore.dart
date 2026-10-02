import 'dart:io';

import '../../../shared/avatar-store/avatar_index.dart';
import '../../calls/data/models/call_log_entry.dart';
import '../../messages/data/models/chat_conversation.dart';
import '../format/backup_file_reader.dart';

/// Gathers everything in a backup that is not a message while the importer
/// reads it; the runner applies it once the file has been read whole.
///
/// Pictures are written straight to where they live (wallpaper folder,
/// avatar folder) through a temp name, and only a complete one is kept —
/// same rule as a restored attachment.
class BackupExtrasCollector {
  BackupExtrasCollector({required this.wallpaperDir, required this.avatarDir});

  final Directory? wallpaperDir;
  final Directory? avatarDir;

  final conversations = <ChatConversation>[];
  final calls = <CallLogEntry>[];
  final prefs = <Map<String, dynamic>>[];
  final avatars = <String, AvatarEntry>{};

  /// Where the old phone kept wallpaper photos; stored paths are moved here.
  String oldWallpaperDir = '';

  Future<void> onFrame(Map<String, dynamic> frame) async {
    try {
      switch (frame['t']) {
        case 'conv':
          final c = ChatConversation.fromJson(
            Map<String, dynamic>.from(frame['c'] as Map),
          );
          if (c.id.isNotEmpty) conversations.add(c);
        case 'call':
          final c = CallLogEntry.fromJson(
            Map<String, dynamic>.from(frame['c'] as Map),
          );
          if (c.id.isNotEmpty) calls.add(c);
        case 'pref':
          prefs.add(frame);
        case 'env':
          oldWallpaperDir = frame['wp'] as String? ?? '';
      }
    } catch (_) {
      // One unreadable frame, never a lost restore.
    }
  }

  Future<BackupFileSink?> onFile(Map<String, dynamic> frame) async {
    final size = (frame['s'] as num?)?.toInt() ?? -1;
    switch (frame['x']) {
      case 'wallpaper':
        final name = _safeName(frame['n']);
        final dir = wallpaperDir;
        if (name == null || dir == null) return null;
        await dir.create(recursive: true);
        return _PictureSink(File('${dir.path}/$name'), size, () async {});
      case 'avatar':
        final name = _safeName(frame['f']);
        final dir = avatarDir;
        final keys = frame['e'];
        if (name == null || dir == null || keys is! Map) return null;
        return _PictureSink(File('${dir.path}/$name'), size, () async {
          for (final e in keys.entries) {
            final entry = AvatarEntry.fromJson(e.value);
            if (entry != null && entry.file == name) {
              avatars[e.key.toString()] = entry;
            }
          }
        });
    }
    return null;
  }

  /// A stored path pointing into the old wallpaper folder, pointed here.
  String rewritePath(String value) {
    final dir = wallpaperDir?.path;
    if (oldWallpaperDir.isEmpty || dir == null || oldWallpaperDir == dir) {
      return value;
    }
    return value.replaceAll(oldWallpaperDir, dir);
  }

  /// A bare file name, never a path out of the folder it is written into.
  static String? _safeName(Object? raw) {
    if (raw is! String || raw.isEmpty || raw.length > 128) return null;
    if (raw.contains('/') || raw.contains('\\') || raw.startsWith('.')) {
      return null;
    }
    return raw;
  }
}

class _PictureSink implements BackupFileSink {
  _PictureSink(this._target, this._expected, this._onDone)
    : _tmp = File('${_target.path}.restore'),
      _sink = File('${_target.path}.restore').openWrite();

  final File _target;
  final File _tmp;
  final IOSink _sink;
  final int _expected;
  final Future<void> Function() _onDone;
  int _written = 0;

  @override
  Future<void> add(List<int> bytes) async {
    _sink.add(bytes);
    _written += bytes.length;
  }

  @override
  Future<void> close() async {
    await _sink.close();
    final complete = _expected < 0 || _written == _expected;
    try {
      // A picture already here is the same name for the same content (avatar
      // names are the URL's hash; wallpapers keep the phone's own copy).
      if (complete && !await _target.exists()) await _tmp.rename(_target.path);
      if (complete) await _onDone();
    } finally {
      try {
        if (await _tmp.exists()) await _tmp.delete();
      } catch (_) {}
    }
  }
}
