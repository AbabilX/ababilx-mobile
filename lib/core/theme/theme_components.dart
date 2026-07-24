import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

AppBarTheme buildAppBarTheme(ColorScheme scheme) {
  final lightIcons = scheme.brightness == Brightness.dark;
  return AppBarTheme(
    backgroundColor: Colors.transparent,
    elevation: 0,
    systemOverlayStyle:
        lightIcons ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    centerTitle: false,
    titleTextStyle: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      color: scheme.onSurface,
    ),
    iconTheme: IconThemeData(color: scheme.onSurface),
  );
}

CardThemeData buildCardTheme(ColorScheme scheme) {
  return CardThemeData(
    color: scheme.surfaceContainerLow,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(28),
      side: BorderSide(color: scheme.outlineVariant),
    ),
  );
}

InputDecorationTheme buildInputTheme(ColorScheme scheme) {
  final muted = scheme.onSurfaceVariant;
  return InputDecorationTheme(
    filled: true,
    fillColor: scheme.surfaceContainerHighest,
    labelStyle: TextStyle(color: muted, fontSize: 13, fontWeight: FontWeight.w500),
    hintStyle: TextStyle(color: muted, fontSize: 13),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: scheme.outline),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: scheme.outline),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: scheme.primary, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: scheme.error),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );
}

NavigationBarThemeData buildNavBarTheme(ColorScheme scheme) {
  return NavigationBarThemeData(
    backgroundColor: scheme.surface,
    elevation: 0,
    height: 72,
    indicatorColor: scheme.primaryContainer,
    indicatorShape: const StadiumBorder(),
    iconTheme: WidgetStateProperty.resolveWith((states) {
      final selected = states.contains(WidgetState.selected);
      return IconThemeData(
        color: selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
        size: 24,
      );
    }),
    labelTextStyle: WidgetStateProperty.resolveWith((states) {
      final selected = states.contains(WidgetState.selected);
      return GoogleFonts.plusJakartaSans(
        color: selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
        fontSize: 12,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      );
    }),
  );
}
