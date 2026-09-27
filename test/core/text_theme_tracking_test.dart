import 'package:ababilx/core/theme/theme_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Tracking splits Bengali vowel signs off their consonants (য়া -> "য় া").
  test('every app text style has zero letter spacing', () {
    // Through ThemeData, as the app builds it: ThemeData fills null
    // letterSpacing back in from Material's defaults.
    final base = ThemeData(useMaterial3: true).textTheme;
    final theme = ThemeData(
      useMaterial3: true,
      textTheme: buildAppTextTheme(const ColorScheme.dark(), base),
    ).textTheme;
    final styles = [
      theme.displayLarge,
      theme.displayMedium,
      theme.displaySmall,
      theme.headlineLarge,
      theme.headlineMedium,
      theme.headlineSmall,
      theme.titleLarge,
      theme.titleMedium,
      theme.titleSmall,
      theme.bodyLarge,
      theme.bodyMedium,
      theme.bodySmall,
      theme.labelLarge,
      theme.labelMedium,
      theme.labelSmall,
    ];
    for (final style in styles) {
      expect(style?.letterSpacing, 0);
    }
  });
}
