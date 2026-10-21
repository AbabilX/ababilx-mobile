import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

/// One ready-made profile picture: a Hugeicons glyph on a soft colour.
///
/// The colours are fixed, not the theme's: the picture is baked into an image
/// file that every other person sees in their own theme, so it must read the
/// same on a light screen and a dark one.
class IconAvatarChoice {
  const IconAvatarChoice(this.icon, this.background, this.ink);

  final List<List<dynamic>> icon;
  final Color background;
  final Color ink;
}

const iconAvatarChoices = <IconAvatarChoice>[
  IconAvatarChoice(
    HugeIcons.strokeRoundedSmile,
    Color(0xFFFFE6A8),
    Color(0xFF8A5A00),
  ),
  IconAvatarChoice(
    HugeIcons.strokeRoundedCat,
    Color(0xFFFFD6CC),
    Color(0xFF9C3A1F),
  ),
  IconAvatarChoice(
    HugeIcons.strokeRoundedRocket01,
    Color(0xFFD7DCFF),
    Color(0xFF3740A8),
  ),
  IconAvatarChoice(
    HugeIcons.strokeRoundedLeaf01,
    Color(0xFFCDEFD6),
    Color(0xFF1E6B35),
  ),
  IconAvatarChoice(
    HugeIcons.strokeRoundedCoffee01,
    Color(0xFFEADBCF),
    Color(0xFF6B4226),
  ),
  IconAvatarChoice(
    HugeIcons.strokeRoundedMusicNote01,
    Color(0xFFF3D3F5),
    Color(0xFF7A2A85),
  ),
  IconAvatarChoice(
    HugeIcons.strokeRoundedSun03,
    Color(0xFFFFE0B8),
    Color(0xFF9A4D00),
  ),
  IconAvatarChoice(
    HugeIcons.strokeRoundedMoon02,
    Color(0xFFD5E3F5),
    Color(0xFF1F3F6B),
  ),
  IconAvatarChoice(
    HugeIcons.strokeRoundedFlower,
    Color(0xFFFFD3E2),
    Color(0xFF9A1F4E),
  ),
  IconAvatarChoice(
    HugeIcons.strokeRoundedFootball,
    Color(0xFFD9F0C8),
    Color(0xFF3B6B12),
  ),
  IconAvatarChoice(
    HugeIcons.strokeRoundedGameController01,
    Color(0xFFC9EEF0),
    Color(0xFF0E6670),
  ),
  IconAvatarChoice(
    HugeIcons.strokeRoundedBook01,
    Color(0xFFE6DEF7),
    Color(0xFF4B3489),
  ),
];
