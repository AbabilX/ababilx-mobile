import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How hard a picture is squeezed before it is sent.
///
/// Signal's two levels. The codes match `MediaQuality` on the Android side —
/// they cross the method channel as ints, so they must not be reordered.
enum MediaQuality {
  standard(0),
  high(1);

  const MediaQuality(this.code);

  final int code;

  static MediaQuality fromCode(int? code) =>
      code == high.code ? high : standard;
}

/// The remembered default, device-local like the chat wallpaper.
///
/// Deliberately not synced and not sent to the server: it describes this
/// phone's connection, not the account. [MediaQuality.standard] is the default
/// because the person picking a photo is rarely the person paying to download
/// it.
class MediaQualityStore {
  const MediaQualityStore();

  static const _key = 'media_quality';

  Future<MediaQuality> read() async {
    final prefs = await SharedPreferences.getInstance();
    return MediaQuality.fromCode(prefs.getInt(_key));
  }

  Future<void> write(MediaQuality quality) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, quality.code);
  }
}

final mediaQualityStoreProvider = Provider(
  (ref) => const MediaQualityStore(),
);

class MediaQualityNotifier extends Notifier<MediaQuality> {
  @override
  MediaQuality build() {
    _load();
    return MediaQuality.standard;
  }

  Future<void> _load() async {
    state = await ref.read(mediaQualityStoreProvider).read();
  }

  /// Called both by the Settings row and by the review screen echoing back
  /// what the user picked there, so the two never disagree.
  Future<void> set(MediaQuality quality) async {
    if (state == quality) return;
    state = quality;
    await ref.read(mediaQualityStoreProvider).write(quality);
  }
}

final mediaQualityProvider = NotifierProvider<MediaQualityNotifier, MediaQuality>(
  MediaQualityNotifier.new,
);
