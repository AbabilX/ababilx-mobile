import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/router/shell_bottom_bar/shell_tabs.dart';

/// Whether Home sits in the bottom bar (Settings → Appearance → Tabs).
/// Device-local, OFF by default: Home is opt-in. Read once in `main` before the first frame,
/// like [StartTab], because the router's redirects are synchronous.
class HomeTabSetting {
  HomeTabSetting._();

  static const _key = 'home_tab_shown_v1';

  static bool _shown = false;

  static bool get shown => _shown;

  static Future<void> preload() async {
    try {
      _shown = await SharedPreferencesAsync().getBool(_key) ?? false;
    } catch (_) {
      _shown = false;
    }
  }

  static Future<void> save(bool shown) async {
    _shown = shown;
    try {
      await SharedPreferencesAsync().setBool(_key, shown);
    } catch (_) {}
  }
}

class HomeTabShownNotifier extends Notifier<bool> {
  @override
  bool build() => HomeTabSetting.shown;

  Future<void> set(bool shown) async {
    await HomeTabSetting.save(shown);
    state = shown;
  }
}

final homeTabShownProvider = NotifierProvider<HomeTabShownNotifier, bool>(
  HomeTabShownNotifier.new,
);

/// The bar's destinations with the user's choice applied: Home only while
/// it is switched on; Messages and Calls always.
List<ShellTab> visibleShellTabs({required bool homeShown}) => [
  for (final t in homeShellTabs)
    if (homeShown || t.route != homeShellTab.route) t,
];

/// The tabs the bar draws right now (callers apply the drag order).
final shownShellTabsProvider = Provider<List<ShellTab>>(
  (ref) => visibleShellTabs(homeShown: ref.watch(homeTabShownProvider)),
);
