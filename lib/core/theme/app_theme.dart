import 'package:flutter/material.dart';

import 'theme_extras.dart';
import 'theme_seed.dart';
import 'theme_text.dart';

/// App themes — jade Material 3, system light/dark via [ThemeMode.system].
/// Brand tokens in `AppColors` stay for future scale.
class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(Brightness.light, lightsOut: false);
  static ThemeData get dark => _build(Brightness.dark, lightsOut: false);
  static ThemeData get lightsOut => _build(Brightness.dark, lightsOut: true);

  static ThemeData _build(Brightness brightness, {required bool lightsOut}) {
    var scheme = ThemeSeed.scheme(brightness);
    if (lightsOut) {
      scheme = scheme.copyWith(
        surface: Colors.black,
        surfaceContainerLowest: Colors.black,
        surfaceContainerLow: const Color(0xFF0A0A0A),
        surfaceContainer: const Color(0xFF121212),
        surfaceContainerHigh: const Color(0xFF1A1A1A),
        surfaceContainerHighest: const Color(0xFF222222),
      );
    }
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: AppFonts.family,
    );
    final textTheme = buildAppTextTheme(scheme, base.textTheme);
    final withText = base.copyWith(
      textTheme: textTheme,
      primaryTextTheme: buildAppTextTheme(scheme, base.primaryTextTheme),
    );
    return applyComponentThemes(withText, scheme);
  }
}
