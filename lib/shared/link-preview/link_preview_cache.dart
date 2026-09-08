import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'link_preview_data.dart';

/// Device-local memory of what each link unfurled to.
///
/// **The key carries a version and it MUST be bumped whenever the metadata
/// source changes.** Misses are cached too, so every link that failed under the
/// previous source would otherwise stay blank on that device for the whole miss
/// window — even after the update that fixed it. That has already bitten twice
/// on desktop.
///
/// v1 is the first on-device fetch (Signal-Android's approach). Before it,
/// mobile called microlink.io, whose free tier is 25 requests per DAY per IP —
/// past that every call is a 429 and the card silently draws nothing, which is
/// exactly what "link previews don't work" looked like. Nothing was cached
/// then, so there is no poisoned v0 to step over.
const _storeKey = 'ababilx_link_preview_v1';

/// A page that answered is worth remembering for a day; one that did not is
/// retried in a couple of hours, so a host that was merely down is not
/// remembered as final.
const _hitTtl = Duration(hours: 24);
const _missTtl = Duration(hours: 2);

/// Oldest entries fall off past this. A chat history is unbounded; this is not.
const _maxEntries = 200;

class LinkPreviewCache {
  LinkPreviewCache._();

  static final LinkPreviewCache instance = LinkPreviewCache._();

  Map<String, _Entry>? _entries;
  Future<void>? _loading;

  Future<void> _ensureLoaded() {
    if (_entries != null) return Future.value();
    return _loading ??= _load();
  }

  Future<void> _load() async {
    final entries = <String, _Entry>{};
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storeKey);
      if (raw != null) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          decoded.forEach((key, value) {
            final entry = _Entry.fromJson(value);
            if (key is String && entry != null && !entry.expired) {
              entries[key] = entry;
            }
          });
        }
      }
    } catch (_) {
      // Unreadable store: start empty rather than lose previews for good.
    }
    _entries = entries;
    _loading = null;
  }

  /// `(true, data)` when this URL is known — `data` null meaning a remembered
  /// miss. `(false, null)` when it has to be fetched. The pair matters: a miss
  /// and an unknown look identical otherwise, and one must not refetch.
  Future<(bool, LinkPreviewData?)> read(String url) async {
    await _ensureLoaded();
    final entry = _entries![url];
    if (entry == null) return (false, null);
    if (entry.expired) {
      _entries!.remove(url);
      return (false, null);
    }
    return (true, entry.data);
  }

  Future<void> write(String url, LinkPreviewData? data) async {
    await _ensureLoaded();
    final entries = _entries!;
    entries[url] = _Entry(DateTime.now().millisecondsSinceEpoch, data);
    entries.removeWhere((_, entry) => entry.expired);
    if (entries.length > _maxEntries) {
      final ordered = entries.entries.toList()
        ..sort((a, b) => a.value.at.compareTo(b.value.at));
      for (final entry in ordered.take(entries.length - _maxEntries)) {
        entries.remove(entry.key);
      }
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _storeKey,
        jsonEncode(entries.map((key, entry) => MapEntry(key, entry.toJson()))),
      );
    } catch (_) {
      // The in-memory copy still serves this session.
    }
  }
}

class _Entry {
  const _Entry(this.at, this.data);

  final int at;
  final LinkPreviewData? data;

  bool get expired {
    final age = DateTime.now().millisecondsSinceEpoch - at;
    return age > (data == null ? _missTtl : _hitTtl).inMilliseconds;
  }

  Map<String, dynamic> toJson() => {'at': at, if (data != null) 'data': data!.toJson()};

  static _Entry? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final at = (raw['at'] as num?)?.toInt();
    if (at == null) return null;
    return _Entry(at, LinkPreviewData.fromJson(raw['data']));
  }
}
