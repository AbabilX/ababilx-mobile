import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

/// One ready-made profile picture: a Hugeicons glyph on a soft colour.
///
/// The colours are fixed, not the theme's: the picture is baked into an image
/// file that every other person sees in their own theme, so it must read the
/// same on a light screen and a dark one.
///
/// Index 0 is the onboarding default — the photo step always starts there and
/// never leaves the picker with no selection.
class IconAvatarChoice {
  const IconAvatarChoice(this.icon, this.background, this.ink);

  final List<List<dynamic>> icon;
  final Color background;
  final Color ink;
}

/// Default onboarding avatar — always selected until the person picks another.
const int iconAvatarDefaultIndex = 0;

const iconAvatarChoices = <IconAvatarChoice>[
  IconAvatarChoice(
    HugeIcons.strokeRoundedSmile,
    Color(0xFFFFE6A8),
    Color(0xFF8A5A00),
  ),
  IconAvatarChoice(
    HugeIcons.strokeRoundedHappy,
    Color(0xFFFFF0C2),
    Color(0xFF8A6200),
  ),
  IconAvatarChoice(
    HugeIcons.strokeRoundedCat,
    Color(0xFFFFD6CC),
    Color(0xFF9C3A1F),
  ),
  IconAvatarChoice(
    HugeIcons.strokeRoundedPanda,
    Color(0xFFE8EEF5),
    Color(0xFF2A3A4A),
  ),
  IconAvatarChoice(
    HugeIcons.strokeRoundedRabbit,
    Color(0xFFFFE0EC),
    Color(0xFF8A2A55),
  ),
  IconAvatarChoice(
    HugeIcons.strokeRoundedBird,
    Color(0xFFD7ECFF),
    Color(0xFF1F5A8A),
  ),
  IconAvatarChoice(
    HugeIcons.strokeRoundedFish,
    Color(0xFFD4F0F5),
    Color(0xFF0E6670),
  ),
  IconAvatarChoice(
    HugeIcons.strokeRoundedTurtle,
    Color(0xFFD5EFD8),
    Color(0xFF1E6B35),
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
    HugeIcons.strokeRoundedGuitar,
    Color(0xFFE8D5F0),
    Color(0xFF5A2A75),
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
    HugeIcons.strokeRoundedCloud,
    Color(0xFFE0EEF8),
    Color(0xFF3A5A7A),
  ),
  IconAvatarChoice(
    HugeIcons.strokeRoundedFire,
    Color(0xFFFFD8C8),
    Color(0xFFB03A10),
  ),
  IconAvatarChoice(
    HugeIcons.strokeRoundedStar,
    Color(0xFFFFF0B8),
    Color(0xFF8A6A00),
  ),
  IconAvatarChoice(
    HugeIcons.strokeRoundedFavourite,
    Color(0xFFFFD6DE),
    Color(0xFFA01F45),
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
    HugeIcons.strokeRoundedBike,
    Color(0xFFD8E8FF),
    Color(0xFF2A4A8A),
  ),
  IconAvatarChoice(
    HugeIcons.strokeRoundedCar01,
    Color(0xFFE0E4F0),
    Color(0xFF3A4060),
  ),
  IconAvatarChoice(
    HugeIcons.strokeRoundedPizza01,
    Color(0xFFFFE4C8),
    Color(0xFF9A4A10),
  ),
  IconAvatarChoice(
    HugeIcons.strokeRoundedCake,
    Color(0xFFFFE0F0),
    Color(0xFF8A3A60),
  ),
  IconAvatarChoice(
    HugeIcons.strokeRoundedIceCream01,
    Color(0xFFFFE8F0),
    Color(0xFF9A3A60),
  ),
  IconAvatarChoice(
    HugeIcons.strokeRoundedApple,
    Color(0xFFFFD8D0),
    Color(0xFF9A2A20),
  ),
  IconAvatarChoice(
    HugeIcons.strokeRoundedBook01,
    Color(0xFFE6DEF7),
    Color(0xFF4B3489),
  ),
  IconAvatarChoice(
    HugeIcons.strokeRoundedPalette,
    Color(0xFFE8DDF5),
    Color(0xFF5A3489),
  ),
  IconAvatarChoice(
    HugeIcons.strokeRoundedCrown,
    Color(0xFFFFE8B8),
    Color(0xFF8A6500),
  ),
  IconAvatarChoice(
    HugeIcons.strokeRoundedAward01,
    Color(0xFFFFE6C8),
    Color(0xFF8A5500),
  ),
];
