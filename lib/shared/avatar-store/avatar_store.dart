import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'avatar_fetch.dart';
import 'avatar_index.dart';
import 'avatar_thumb.dart';

/// Profile and group pictures as files on this phone, looked up synchronously
/// — the reference app's `AvatarHelper` (one file per recipient) plus the
/// `profile_avatar` column that says which URL that file came from.
///
/// A key is an OWNER (`user:<id>`, `conv:<id>`) or, where no owner is known,
/// the URL itself. When an owner's URL changes, the picture already on disk
/// keeps being drawn while the new one downloads, then swaps in — the reference
/// app's `RetrieveProfileAvatarJob` writes the new file before anything reads
/// it, so nobody ever sees a letter where a face used to be.
class AvatarStore {
  AvatarStore._();

  static final AvatarStore instance = AvatarStore._();

  Directory? _dir;
  AvatarIndex? _index;
  final Map<String, AvatarEntry> _entries = {};
  final Map<String, Future<File?>> _inFlight = {};
  final Map<String, DateTime> _failedAt = {};
  final Map<String, ValueNotifier<int>> _changes = {};

  static const _retryAfter = Duration(minutes: 10);

  /// Reads the index. Awaited before the first frame, so the chat list's
  /// first paint already knows which faces are on disk.
  Future<void> init() async {
    if (_dir != null) return;
    try {
      final base = await getApplicationSupportDirectory();
      final dir = Directory('${base.path}/avatars');
      await dir.create(recursive: true);
      final index = AvatarIndex(File('${dir.path}/index.json'));
      _entries.addAll(await index.load());
      _index = index;
      _dir = dir;
    } catch (error) {
      debugPrint('[AvatarStore] init failed: $error');
    }
  }

  /// Google profile pictures are asked for at the stored size.
  static String? normalize(String? raw) {
    final url = raw?.trim();
    if (url == null || url.isEmpty) return null;
    if (url.contains('googleusercontent.com')) {
      return url.replaceFirst(RegExp(r'=s\d+-c'), '=s${AvatarThumb.side}-c');
    }
    return url;
  }

  /// Ticks when the picture behind [key] changes.
  ValueListenable<int> changes(String key) =>
      _changes.putIfAbsent(key, () => ValueNotifier<int>(0));

  /// The file to draw for [url] right now, or null when nothing is on disk
  /// yet. Never waits: a missing or outdated picture is fetched behind it.
  File? fileFor(String? url, {String? owner}) {
    final dir = _dir;
    final u = normalize(url);
    if (dir == null || u == null) return null;
    if (owner != null) {
      final mine = _entries[owner];
      if (mine != null) {
        if (mine.url != u) unawaited(ensure(u, owner: owner));
        return File('${dir.path}/${mine.file}');
      }
    }
    final known = _entries[u];
    if (known != null) {
      if (owner != null) _link(owner, known, notify: false);
      return File('${dir.path}/${known.file}');
    }
    unawaited(ensure(u, owner: owner));
    return null;
  }

  /// Puts [url]'s picture on disk (once, however many ask) and, with an
  /// [owner], points that owner at it.
  Future<File?> ensure(String url, {String? owner}) async {
    final dir = _dir;
    final u = normalize(url);
    if (dir == null || u == null) return null;
    final known = _entries[u];
    if (known != null) {
      final file = File('${dir.path}/${known.file}');
      if (await file.exists()) {
        if (owner != null) _link(owner, known, notify: true);
        return file;
      }
      _entries.remove(u);
    }
    final failed = _failedAt[u];
    if (failed != null && DateTime.now().difference(failed) < _retryAfter) {
      return null;
    }
    final file = await (_inFlight[u] ??= _download(
      dir,
      u,
    ).whenComplete(() => _inFlight.remove(u)));
    final landed = _entries[u];
    if (file != null && owner != null && landed != null) {
      _link(owner, landed, notify: true);
    }
    return file;
  }

  /// Backup: the index as it stands, and where its files live.
  Map<String, AvatarEntry> get entries => Map.unmodifiable(_entries);
  Directory? get directory => _dir;

  /// Restore: [keys] now point at [file] (already in [directory]). A key
  /// this phone holds already keeps its own picture.
  void adoptRestored(Map<String, AvatarEntry> keys) {
    for (final e in keys.entries) {
      if (_entries.containsKey(e.key)) continue;
      _entries[e.key] = e.value;
      _notify(e.key);
    }
    _save();
  }

  /// A stored file that would not decode: drop it so it is fetched again.
  void forget(File file) {
    final name = file.uri.pathSegments.last;
    final keys = [
      for (final e in _entries.entries)
        if (e.value.file == name) e.key,
    ];
    for (final key in keys) {
      _entries.remove(key);
      _notify(key);
    }
    unawaited(file.delete().then((_) {}, onError: (_) {}));
    _save();
  }

  Future<File?> _download(Directory dir, String url) async {
    try {
      final bytes = await AvatarFetch.bytes(url);
      final stored = bytes == null ? null : await AvatarThumb.shrink(bytes);
      if (stored == null) {
        _failedAt[url] = DateTime.now();
        return null;
      }
      final name = sha1.convert(utf8.encode(url)).toString();
      final file = File('${dir.path}/$name');
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsBytes(stored, flush: true);
      await tmp.rename(file.path);
      _failedAt.remove(url);
      _entries[url] = AvatarEntry(url: url, file: name, at: _now());
      _notify(url);
      _save();
      return file;
    } catch (error) {
      debugPrint('[AvatarStore] download failed: $error');
      _failedAt[url] = DateTime.now();
      return null;
    }
  }

  void _link(String owner, AvatarEntry entry, {required bool notify}) {
    final old = _entries[owner];
    if (old?.file == entry.file) return;
    _entries[owner] = AvatarEntry(url: entry.url, file: entry.file, at: _now());
    if (notify) _notify(owner);
    _save();
  }

  void _save() {
    final dir = _dir;
    for (final key in AvatarIndex.overflow(_entries)) {
      final gone = _entries.remove(key);
      if (gone == null || dir == null) continue;
      if (_entries.values.any((e) => e.file == gone.file)) continue;
      File('${dir.path}/${gone.file}').delete().then((_) {}, onError: (_) {});
    }
    _index?.scheduleSave(_entries);
  }

  void _notify(String key) => _changes[key]?.value++;

  static int _now() => DateTime.now().millisecondsSinceEpoch;
}
