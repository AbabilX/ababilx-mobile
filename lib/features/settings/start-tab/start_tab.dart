import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../appearance/home_tab_setting.dart';

/// Which bottom-bar tab the app opens on (Settings → Open on launch).
/// Device-local. Read once in `main` before the first frame, because the
/// router's redirect that leaves the launch screen is synchronous.
class StartTab {
  StartTab._();

  static const _key = 'start_tab_v1';
  static const fallback = '/messages';

  static String _route = fallback;

  /// The tab route to land on; Messages until the user picks another, and
  /// Messages again while the picked tab is hidden from the bar.
  static String get route => sanitize(_route);

  /// Only a route the bar still shows is honoured; anything else is Messages.
  static String sanitize(String? route) =>
      visibleShellTabs(
        homeShown: HomeTabSetting.shown,
      ).any((t) => t.route == route)
      ? route!
      : fallback;

  static Future<void> preload() async {
    try {
      _route = await SharedPreferencesAsync().getString(_key) ?? fallback;
    } catch (_) {
      _route = fallback;
    }
  }

  static Future<void> save(String route) async {
    _route = route;
    try {
      await SharedPreferencesAsync().setString(_key, _route);
    } catch (_) {}
  }
}

class StartTabNotifier extends Notifier<String> {
  @override
  String build() {
    // Hiding Home while it was the launch tab falls back to Messages; the
    // saved choice is kept, so showing Home again brings it back.
    ref.watch(homeTabShownProvider);
    return StartTab.route;
  }

  Future<void> choose(String route) async {
    await StartTab.save(route);
    state = StartTab.route;
  }
}

final startTabProvider = NotifierProvider<StartTabNotifier, String>(
  StartTabNotifier.new,
);
