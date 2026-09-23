import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'chat_wallpaper_store.dart';

/// Photos the user has set as a wallpaper, newest first, so they can pick one
/// again from the wallpaper page instead of hunting through the gallery.
///
/// Each is COPIED into app support: the gallery hands back a cache file, and
/// the OS may clear a cache whenever it likes — a wallpaper that turned blank
/// one morning. The key deliberately does not start with the wallpaper
/// store's per-chat prefix, or "reset every chat" would wipe this list.
class ChatWallpaperPhotosNotifier extends AsyncNotifier<List<String>> {
  static const String _key = 'ababilx_wallpaper_photos_v1';
  static const int maxPhotos = 12;

  @override
  Future<List<String>> build() async {
    final prefs = await SharedPreferences.getInstance();
    final paths = prefs.getStringList(_key) ?? const [];
    return [
      for (final path in paths)
        if (await File(path).exists()) path,
    ];
  }

  /// Keeps [source] in the list and returns the path to paint from. A photo
  /// already kept only moves to the front.
  Future<String> keep(String source) async {
    final dir = await _dir();
    var kept = source;
    if (!p.isWithin(dir.path, source)) {
      final name =
          '${DateTime.now().microsecondsSinceEpoch}'
          '${p.extension(source)}';
      kept = (await File(source).copy(p.join(dir.path, name))).path;
    }
    final current = await future;
    final next = [kept, ...current.where((path) => path != kept)];
    final evicted = next.length > maxPhotos ? next.sublist(maxPhotos) : [];
    await _save(next.take(maxPhotos).toList());
    for (final path in evicted) {
      await _deleteIfUnused(path);
    }
    return kept;
  }

  /// Drops [path] from the list. The file goes too unless a chat still
  /// paints it — that chat keeps its wallpaper.
  Future<void> remove(String path) async {
    final current = await future;
    await _save(current.where((item) => item != path).toList());
    await _deleteIfUnused(path);
  }

  Future<void> _save(List<String> paths) async {
    state = AsyncData(paths);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, paths);
  }

  Future<void> _deleteIfUnused(String path) async {
    if (await const ChatWallpaperStore().photoInUse(path)) return;
    try {
      await File(path).delete();
    } on FileSystemException {
      // Already gone; nothing to free.
    }
  }

  static Future<Directory> _dir() async {
    final root = await getApplicationSupportDirectory();
    return Directory(
      p.join(root.path, 'chat_wallpapers'),
    ).create(recursive: true);
  }
}

final chatWallpaperPhotosProvider =
    AsyncNotifierProvider<ChatWallpaperPhotosNotifier, List<String>>(
      ChatWallpaperPhotosNotifier.new,
    );
