import 'package:flutter/material.dart';

/// Bundled UI typefaces. Latin glyphs come from Lato; Bengali falls
/// through to Noto Sans Bengali (weights 400-900). Glyphs neither has (archaic vocalics,
/// currency fractions) come from the system font. Login wordmark stays
/// Fredoka.
abstract final class AppFonts {
  static const family = 'Lato';
  static const fallback = <String>['NotoSansBengali'];
}

TextTheme buildAppTextTheme(ColorScheme scheme, TextTheme base) {
  final on = scheme.onSurface;
  final themed = base
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
  // Last, so the whole-style overrides above cannot bring tracking back.
  return _withoutTracking(themed);
}

/// Material's styles carry letterSpacing (0.1-0.5). Tracking is added
/// between glyphs, and in Bengali that pulls a vowel sign (া ি ী ে) or a
/// nukta off its consonant: য়া reads "য় া", মি splits. Every style starts at
/// 0 so Bangla shapes as one cluster; a style that sets its own tracking
/// must not do it on text that can be Bangla (see `latinTracking`).
TextTheme _withoutTracking(TextTheme t) {
  TextStyle? z(TextStyle? s) => s?.copyWith(letterSpacing: 0);
  return t.copyWith(
    displayLarge: z(t.displayLarge),
    displayMedium: z(t.displayMedium),
    displaySmall: z(t.displaySmall),
    headlineLarge: z(t.headlineLarge),
    headlineMedium: z(t.headlineMedium),
    headlineSmall: z(t.headlineSmall),
    titleLarge: z(t.titleLarge),
    titleMedium: z(t.titleMedium),
    titleSmall: z(t.titleSmall),
    bodyLarge: z(t.bodyLarge),
    bodyMedium: z(t.bodyMedium),
    bodySmall: z(t.bodySmall),
    labelLarge: z(t.labelLarge),
    labelMedium: z(t.labelMedium),
    labelSmall: z(t.labelSmall),
  );
}
