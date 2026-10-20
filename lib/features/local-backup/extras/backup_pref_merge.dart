import 'dart:convert';

/// Settings that are LISTS, which a restore merges instead of skipping.
///
/// For a single value "the phone's wins" is right: a choice made since the
/// backup is newer than the backup's. A list is different — the phone's
/// favourites and the backup's are both the person's, and keeping only the
/// phone's dropped every one the backup held the moment the phone had saved
/// a single entry. The phone's entries stay first and in their order; the
/// backup's fill in after them, never twice, up to the list's own cap.
abstract final class BackupPrefMerge {
  static const favoritesPrefix = 'call_favorites_v1:';
  static const wallpaperPhotos = 'ababilx_wallpaper_photos_v1';

  /// The lists' own caps (`CallFavoritesNotifier.maxFavorites`,
  /// `ChatWallpaperPhotosNotifier.maxPhotos`).
  static const favoritesCap = 12;
  static const wallpaperPhotosCap = 12;

  static bool merges(String key) =>
      key == wallpaperPhotos || key.startsWith(favoritesPrefix);

  /// The value to store for [key], or null to leave the phone's as it is.
  /// [phone] and [backup] are the stored values (backup already rewritten).
  static Object? merge(String key, Object? phone, Object? backup) {
    if (key == wallpaperPhotos) {
      if (phone is! List || backup is! List) return null;
      return _union(
        [for (final p in phone) p.toString()],
        [for (final p in backup) p.toString()],
        (p) => p,
        wallpaperPhotosCap,
      );
    }
    if (key.startsWith(favoritesPrefix)) {
      if (phone is! String || backup is! String) return null;
      final mine = _jsonList(phone);
      final theirs = _jsonList(backup);
      if (mine == null || theirs == null) return null;
      final merged = _union(mine, theirs, _favoriteId, favoritesCap);
      return merged == null ? null : jsonEncode(merged);
    }
    return null;
  }

  static String? _favoriteId(Object? entry) =>
      entry is Map ? entry['c']?.toString() : null;

  static List<Object?>? _jsonList(String raw) {
    try {
      final list = jsonDecode(raw);
      return list is List ? list : null;
    } catch (_) {
      return null;
    }
  }

  /// [phone] then the [backup] entries it lacks; null when nothing is added.
  static List<T>? _union<T>(
    List<T> phone,
    List<T> backup,
    String? Function(T) idOf,
    int cap,
  ) {
    final seen = {for (final e in phone) ?idOf(e)};
    final out = [...phone];
    for (final e in backup) {
      if (out.length >= cap) break;
      final id = idOf(e);
      if (id == null || id.isEmpty || !seen.add(id)) continue;
      out.add(e);
    }
    return out.length == phone.length ? null : out;
  }
}
