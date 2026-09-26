import 'package:flutter/material.dart';

/// Bundled UI typefaces. Latin glyphs come from Lato; Bengali falls
/// through to Li Shohid Abu Sayed. Glyphs neither has (archaic vocalics,
/// currency fractions) come from the system font. Login wordmark stays
/// Fredoka.
abstract final class AppFonts {
  static const family = 'Lato';
  static const fallback = <String>['ShohidAbuSayed'];
}

TextTheme buildAppTextTheme(ColorScheme scheme, TextTheme base) {
  final on = scheme.onSurface;
  return base
      .copyWith(
        displayLarge: TextStyle(
          fontSize: 57,
          fontWeight: FontWeight.w800,
          color: on,
        ),
        displayMedium: TextStyle(
          fontSize: 45,
          fontWeight: FontWeight.w800,
          color: on,
        ),
        displaySmall: TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.w800,
          color: on,
        ),
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          color: on,
        ),
        headlineMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: on,
        ),
        headlineSmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: on,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: on,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: on,
        ),
        titleSmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: on,
        ),
      )
      .apply(
        fontFamily: AppFonts.family,
        fontFamilyFallback: AppFonts.fallback,
        bodyColor: on,
        displayColor: on,
      );
}
