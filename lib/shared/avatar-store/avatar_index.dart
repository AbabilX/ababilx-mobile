import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// One picture on disk: the URL it was downloaded from and the file name it
/// lives under inside the avatar directory.
@immutable
class AvatarEntry {
  const AvatarEntry({required this.url, required this.file, required this.at});

  final String url;
  final String file;

  /// When this key last pointed somewhere new, in ms — the trim's ordering.
  final int at;

  Map<String, Object> toJson() => {'u': url, 'f': file, 't': at};

  static AvatarEntry? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final url = raw['u'];
    final file = raw['f'];
    if (url is! String || file is! String) return null;
    final at = raw['t'];
    return AvatarEntry(url: url, file: file, at: at is int ? at : 0);
  }
}

/// The avatar store's map from key (an owner such as `user:<id>`, or a bare
/// URL) to the file holding its picture — the reference app's
/// `recipient.profile_avatar` column beside `AvatarHelper`'s files, as one
/// small JSON file.
///
/// Read once before the first frame, so every lookup after it is synchronous.
/// Writes are coalesced: a prefetch landing fifty pictures writes once.
class AvatarIndex {
  AvatarIndex(this._file);

  final File _file;
  Timer? _flush;

  static const _maxEntries = 3000;

  Future<Map<String, AvatarEntry>> load() async {
    final out = <String, AvatarEntry>{};
    try {
      if (!await _file.exists()) return out;
      final raw = jsonDecode(await _file.readAsString());
      if (raw is! Map) return out;
      raw.forEach((key, value) {
        final entry = AvatarEntry.fromJson(value);
        if (key is String && entry != null) out[key] = entry;
      });
    } catch (error) {
      debugPrint('[AvatarStore] index unreadable, starting empty: $error');
    }
    return out;
  }

  /// Writes [entries] shortly, once, however many changes ask for it.
  void scheduleSave(Map<String, AvatarEntry> entries) {
    _flush?.cancel();
    _flush = Timer(const Duration(milliseconds: 800), () => _save(entries));
  }

  Future<void> _save(Map<String, AvatarEntry> entries) async {
    try {
      final json = jsonEncode({
        for (final e in entries.entries) e.key: e.value.toJson(),
      });
      final tmp = File('${_file.path}.tmp');
      await tmp.writeAsString(json, flush: true);
      await tmp.rename(_file.path);
    } catch (error) {
      debugPrint('[AvatarStore] index write failed: $error');
    }
  }

  /// Keys to drop once the index outgrows its cap, oldest first. Owner keys
  /// (the chat list's people and groups) outlive bare-URL keys.
  static List<String> overflow(Map<String, AvatarEntry> entries) {
    final extra = entries.length - _maxEntries;
    if (extra <= 0) return const [];
    final keys = entries.keys.toList()
      ..sort((a, b) {
        final owner = _isOwner(a) == _isOwner(b) ? 0 : (_isOwner(a) ? 1 : -1);
        if (owner != 0) return owner;
        return entries[a]!.at.compareTo(entries[b]!.at);
      });
    return keys.take(extra).toList();
  }

  static bool _isOwner(String key) => !key.startsWith('http');
}
