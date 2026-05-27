import 'package:flutter/material.dart';

/// Design tokens mirroring the website globals.css exactly.
class AppColors {
  AppColors._();

  // Backgrounds
  static const Color bg = Color(0xFF050508);
  static const Color surface = Color(0xFF0C0C14);
  static const Color surface2 = Color(0xFF111120);
  static const Color surface3 = Color(0x08FFFFFF); // rgba(255,255,255,0.03)

  // Borders
  static const Color border = Color(0x0FFFFFFF); // rgba(255,255,255,0.06)
  static const Color borderHover = Color(0x1FFFFFFF); // rgba(255,255,255,0.12)

  // Accent
  static const Color indigo = Color(0xFF6366F1);
  static const Color indigoLight = Color(0xFF818CF8);
  static const Color indigoGlow = Color(0x406366F1); // rgba(99,102,241,0.25)

  // Status
  static const Color green = Color(0xFF22C55E);
  static const Color red = Color(0xFFEF4444);
  static const Color amber = Color(0xFFF59E0B);

  // Text
  static const Color text = Color(0xFFF1F5F9);
  static const Color textMuted = Color(0xFF64748B);
  static const Color textDim = Color(0xFF334155);

  // Gradients
  static const LinearGradient indigoGradient = LinearGradient(
    colors: [indigo, indigoLight],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}
