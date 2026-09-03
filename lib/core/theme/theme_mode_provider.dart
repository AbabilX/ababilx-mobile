import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme_mode_store.dart';

final themeModeStoreProvider = Provider((_) => const ThemeModeStore());

/// No stored choice yet means follow the OS ([ThemeMode.system]). Setting one
/// picks it explicitly; [setMode] with `ThemeMode.system` clears it back.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  bool _disposed = false;

  @override
  ThemeMode build() {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    _load();
    return ThemeMode.system;
  }

  ThemeModeStore get _store => ref.read(themeModeStoreProvider);

  Future<void> _load() async {
    final isDark = await _store.read();
    if (_disposed || isDark == null) return;
    state = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    await _store.write(
      mode == ThemeMode.system ? null : mode == ThemeMode.dark,
    );
  }

  /// System -> Light -> Dark -> System.
  Future<void> cycle() {
    const order = [ThemeMode.system, ThemeMode.light, ThemeMode.dark];
    final next = order[(order.indexOf(state) + 1) % order.length];
    return setMode(next);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
