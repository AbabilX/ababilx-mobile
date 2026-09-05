import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/network_class.dart';
import 'auto_download_settings.dart';

/// Device-local, like the chat wallpaper and sent-media quality.
///
/// Never synced: it describes what this phone's connection costs, not
/// something true of the account. A tablet on Wi-Fi and a phone on a metered
/// SIM want opposite answers.
///
/// Holds an in-memory copy so the auto-download gate — which runs on the
/// arrival path of every message, with no widget behind it — can read the real
/// setting rather than a default that has not finished loading yet.
class AutoDownloadStore {
  AutoDownloadStore();

  static const _keyPrefix = 'auto_download_';

  AutoDownloadSettings? _cache;

  Future<AutoDownloadSettings> read() async {
    final cached = _cache;
    if (cached != null) return cached;
    try {
      final prefs = await SharedPreferences.getInstance();
      final masks = <AutoDownloadMedia, int>{};
      for (final media in AutoDownloadMedia.values) {
        masks[media] =
            prefs.getInt('$_keyPrefix${media.name}') ??
            AutoDownloadSettings.defaults.maskFor(media);
      }
      return _cache = AutoDownloadSettings(masks);
    } catch (_) {
      return AutoDownloadSettings.defaults;
    }
  }

  Future<void> write(AutoDownloadSettings settings) async {
    _cache = settings;
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final media in AutoDownloadMedia.values) {
        await prefs.setInt('$_keyPrefix${media.name}', settings.maskFor(media));
      }
    } catch (_) {
      // A failed write loses the choice on the next launch, never in this
      // session — the cache above is what the gate reads.
    }
  }
}

final autoDownloadStoreProvider = Provider<AutoDownloadStore>(
  (ref) => AutoDownloadStore(),
);

/// UI-facing state. Starts at the defaults and settles on the stored value one
/// frame later, the same shape the media-quality setting uses.
class AutoDownloadNotifier extends Notifier<AutoDownloadSettings> {
  @override
  AutoDownloadSettings build() {
    _load();
    return AutoDownloadSettings.defaults;
  }

  Future<void> _load() async {
    state = await ref.read(autoDownloadStoreProvider).read();
  }

  Future<void> setNetworks(
    AutoDownloadMedia media,
    Set<AutoDownloadNetwork> networks,
  ) async {
    final next = state.withNetworks(media, networks);
    state = next;
    await ref.read(autoDownloadStoreProvider).write(next);
  }
}

final autoDownloadSettingsProvider =
    NotifierProvider<AutoDownloadNotifier, AutoDownloadSettings>(
      AutoDownloadNotifier.new,
    );
