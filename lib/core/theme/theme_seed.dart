import 'package:flutter/material.dart';

/// Jade Material 3 seed — kept for future scale / brand tweaks.
abstract final class ThemeSeed {
  static const Color jade = Color(0xFF0F766E);

  static ColorScheme scheme(Brightness brightness) =>
      ColorScheme.fromSeed(seedColor: jade, brightness: brightness);
}
