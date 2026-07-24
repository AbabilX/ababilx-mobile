import 'package:flutter/material.dart';

import 'theme_extras.dart';
import 'theme_seed.dart';
import 'theme_text.dart';

/// App themes — jade Material 3, system light/dark via [ThemeMode.system].
/// Brand tokens in `AppColors` stay for future scale.
class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ThemeSeed.scheme(brightness);
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
    );
    final withText = base.copyWith(
      textTheme: buildAppTextTheme(scheme, base.textTheme),
    );
    return applyComponentThemes(withText, scheme);
  }
}
