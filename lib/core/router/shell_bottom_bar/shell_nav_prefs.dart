import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device-local which workspace tabs appear in the home bottom bar.
///
/// Defaults are all-on: a fresh install shows Wall / CRM / Board whenever the
/// account has access. Turning a switch off only hides the tab chrome — deep
/// links and in-app routes to those screens still work.
class ShellNavPrefs {
  const ShellNavPrefs({
    this.showWall = true,
    this.showCrm = true,
    this.showBoard = true,
  });

  final bool showWall;
  final bool showCrm;
  final bool showBoard;

  static const defaults = ShellNavPrefs();

  ShellNavPrefs copyWith({bool? showWall, bool? showCrm, bool? showBoard}) =>
      ShellNavPrefs(
        showWall: showWall ?? this.showWall,
        showCrm: showCrm ?? this.showCrm,
        showBoard: showBoard ?? this.showBoard,
      );
}

/// SharedPreferences keys for [ShellNavPrefs]. Missing keys mean "show".
class ShellNavPrefsStore {
  const ShellNavPrefsStore();

  static const _wallKey = 'ababilx_shell_nav_wall';
  static const _crmKey = 'ababilx_shell_nav_crm';
  static const _boardKey = 'ababilx_shell_nav_board';

  Future<ShellNavPrefs> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return ShellNavPrefs(
        showWall: prefs.getBool(_wallKey) ?? true,
        showCrm: prefs.getBool(_crmKey) ?? true,
        showBoard: prefs.getBool(_boardKey) ?? true,
      );
    } catch (_) {
      return ShellNavPrefs.defaults;
    }
  }

  Future<void> write(ShellNavPrefs value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_wallKey, value.showWall);
      await prefs.setBool(_crmKey, value.showCrm);
      await prefs.setBool(_boardKey, value.showBoard);
    } catch (_) {
      // Session still has the in-memory notifier state; next launch falls back
      // to defaults only if the write never landed.
    }
  }
}

final shellNavPrefsStoreProvider = Provider<ShellNavPrefsStore>(
  (ref) => const ShellNavPrefsStore(),
);

/// Starts at all-visible, then settles on the stored value after the first
/// prefs read — same shape as auto-download / media-quality settings.
class ShellNavPrefsNotifier extends Notifier<ShellNavPrefs> {
  @override
  ShellNavPrefs build() {
    _load();
    return ShellNavPrefs.defaults;
  }

  Future<void> _load() async {
    state = await ref.read(shellNavPrefsStoreProvider).read();
  }

  Future<void> setShowWall(bool value) => _set(state.copyWith(showWall: value));

  Future<void> setShowCrm(bool value) => _set(state.copyWith(showCrm: value));

  Future<void> setShowBoard(bool value) =>
      _set(state.copyWith(showBoard: value));

  Future<void> _set(ShellNavPrefs next) async {
    state = next;
    await ref.read(shellNavPrefsStoreProvider).write(next);
  }
}

final shellNavPrefsProvider =
    NotifierProvider<ShellNavPrefsNotifier, ShellNavPrefs>(
      ShellNavPrefsNotifier.new,
    );
