import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _key = 'local_share_quick_button_v1';

/// Whether the home bar carries a separate round Local Share button beside
/// its pill. A choice about this phone's screen, so it lives on the phone,
/// off until the user turns it on in Local Share.
class ShareQuickButtonNotifier extends Notifier<bool> {
  @override
  bool build() {
    _load();
    return false;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = prefs.getBool(_key) ?? false;
    } catch (_) {
      // Unreadable storage leaves the button off.
    }
  }

  Future<void> set(bool on) async {
    state = on;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, on);
    } catch (_) {
      // The switch still works for this run.
    }
  }
}

final shareQuickButtonProvider =
    NotifierProvider<ShareQuickButtonNotifier, bool>(
      ShareQuickButtonNotifier.new,
    );
