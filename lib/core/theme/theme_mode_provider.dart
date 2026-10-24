import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme_mode_store.dart';

enum AppThemeMode { system, light, dark, lightsOut }

final themeModeStoreProvider = Provider((_) => const ThemeModeStore());

/// No stored choice yet means follow the OS ([AppThemeMode.system]). Setting one
/// picks it explicitly; [setMode] with `AppThemeMode.system` clears it back.
class ThemeModeNotifier extends Notifier<AppThemeMode> {
  bool _disposed = false;

  @override
  AppThemeMode build() {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    _load();
    return AppThemeMode.system;
  }

  ThemeModeStore get _store => ref.read(themeModeStoreProvider);

  Future<void> _load() async {
    final mode = await _store.read();
    if (_disposed || mode == null) return;
    state = mode;
  }

  Future<void> setMode(AppThemeMode mode) async {
    state = mode;
    await _store.write(mode);
  }

  /// System -> Light -> Dark -> Lights Out -> System.
  Future<void> cycle() {
    const order = [
      AppThemeMode.system,
      AppThemeMode.light,
      AppThemeMode.dark,
      AppThemeMode.lightsOut,
    ];
    final next = order[(order.indexOf(state) + 1) % order.length];
    return setMode(next);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, AppThemeMode>(
  ThemeModeNotifier.new,
);
