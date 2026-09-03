import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme_mode_store.dart';

final themeModeStoreProvider = Provider((_) => const ThemeModeStore());

/// No stored choice yet means follow the OS. Toggling picks one explicitly.
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

  Future<void> setDark(bool isDark) async {
    state = isDark ? ThemeMode.dark : ThemeMode.light;
    await _store.write(isDark);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
