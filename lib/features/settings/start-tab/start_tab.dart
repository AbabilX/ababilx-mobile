import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/router/shell_bottom_bar/shell_tabs.dart';

/// Which bottom-bar tab the app opens on (Settings → Open on launch).
/// Device-local. Read once in `main` before the first frame, because the
/// router's redirect that leaves the launch screen is synchronous.
class StartTab {
  StartTab._();

  static const _key = 'start_tab_v1';
  static const fallback = '/messages';

  static String _route = fallback;

  /// The tab route to land on; Messages until the user picks another.
  static String get route => _route;

  /// Only a route the bar still has is honoured; anything else is Messages.
  static String sanitize(String? route) =>
      homeShellTabs.any((t) => t.route == route) ? route! : fallback;

  static Future<void> preload() async {
    try {
      _route = sanitize(await SharedPreferencesAsync().getString(_key));
    } catch (_) {
      _route = fallback;
    }
  }

  static Future<void> save(String route) async {
    _route = sanitize(route);
    try {
      await SharedPreferencesAsync().setString(_key, _route);
    } catch (_) {}
  }
}

class StartTabNotifier extends Notifier<String> {
  @override
  String build() => StartTab.route;

  Future<void> choose(String route) async {
    await StartTab.save(route);
    state = StartTab.route;
  }
}

final startTabProvider = NotifierProvider<StartTabNotifier, String>(
  StartTabNotifier.new,
);
