import 'package:flutter/material.dart';

import 'theme_components.dart';

SwitchThemeData buildSwitchTheme(ColorScheme scheme) {
  return SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return scheme.onPrimary;
      }
      return scheme.outline;
    }),
    trackColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return scheme.primary;
      }
      return scheme.surfaceContainerHighest;
    }),
  );
}

ChipThemeData buildChipTheme(ColorScheme scheme) {
  return ChipThemeData(
    backgroundColor: scheme.surfaceContainerHighest,
    selectedColor: scheme.primaryContainer,
    labelStyle: TextStyle(
      color: scheme.onSurface,
      fontSize: 13,
      fontWeight: FontWeight.w600,
    ),
    side: BorderSide(color: scheme.outlineVariant),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  );
}

SnackBarThemeData buildSnackBarTheme(ColorScheme scheme) {
  return SnackBarThemeData(
    backgroundColor: scheme.inverseSurface,
    contentTextStyle: TextStyle(color: scheme.onInverseSurface),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: scheme.outlineVariant),
    ),
    behavior: SnackBarBehavior.floating,
  );
}

/// Shared component themes applied on top of a ColorScheme.
ThemeData applyComponentThemes(ThemeData base, ColorScheme scheme) {
  return base.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: buildAppBarTheme(scheme),
    cardTheme: buildCardTheme(scheme),
    inputDecorationTheme: buildInputTheme(scheme),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      thickness: 0.8,
    ),
    navigationBarTheme: buildNavBarTheme(scheme),
    switchTheme: buildSwitchTheme(scheme),
    chipTheme: buildChipTheme(scheme),
    snackBarTheme: buildSnackBarTheme(scheme),
  );
}
