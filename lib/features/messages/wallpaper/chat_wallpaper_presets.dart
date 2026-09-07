import 'package:flutter/material.dart';

/// Both bundled paintings are anchored to this corner wherever they are drawn
/// — grid tile, preview and the chat itself.
///
/// A phone screen is much taller than either picture, so `cover` scales them
/// past the viewport and crops the overflow. Both were composed with their
/// subject low and to the left, so centring the crop cuts the flowers off and
/// leaves an empty sky.
const Alignment chatWallpaperArtAlignment = Alignment.bottomLeft;

const String chatWallpaperDewdropId = 'dewdrop';
const String chatWallpaperRainyPaddyId = 'rainy-paddy';

/// One of the built-in backgrounds.
@immutable
class ChatWallpaperPreset {
  const ChatWallpaperPreset(this.id, this.colors, {this.asset});

  final String id;

  /// One colour paints flat; two or more paint as a diagonal gradient, which
  /// is how Signal's preset set is built.
  final List<Color> colors;

  /// A bundled painting. When set it is what actually shows and [colors] is
  /// only the ground under it, so a tile is never blank while the image
  /// decodes.
  final String? asset;

  bool get isArt => asset != null;

  Gradient? get gradient => fadedGradient(1);

  /// The gradient with [opacity] folded into every stop, or null when this
  /// preset is a flat colour.
  Gradient? fadedGradient(double opacity) => colors.length < 2
      ? null
      : LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            for (final color in colors) color.withValues(alpha: opacity),
          ],
        );

  Color get solid => colors.first;
}

/// The built-in set. The two paintings lead, then solids, then gradients, so
/// the grid reads left-to-right from loud to calm.
///
/// None of them is a default: a chat with no stored choice paints no wallpaper
/// at all, the same as before these existed.
const List<ChatWallpaperPreset> chatWallpaperPresets = [
  ChatWallpaperPreset(
    chatWallpaperDewdropId,
    [Color(0xFF9CC77E)],
    asset: 'assets/images/wallpapers/dewdrop_field.jpg',
  ),
  ChatWallpaperPreset(
    chatWallpaperRainyPaddyId,
    [Color(0xFF4E6B4A)],
    asset: 'assets/images/wallpapers/rainy_paddy.jpg',
  ),
  ChatWallpaperPreset('slate', [Color(0xFF1F2430)]),
  ChatWallpaperPreset('ink', [Color(0xFF0F172A)]),
  ChatWallpaperPreset('sand', [Color(0xFFEFE7DA)]),
  ChatWallpaperPreset('mist', [Color(0xFFE6ECF5)]),
  ChatWallpaperPreset('sage', [Color(0xFFDDE9DF)]),
  ChatWallpaperPreset('rose', [Color(0xFFF6E2E6)]),
  ChatWallpaperPreset('indigo', [Color(0xFF6366F1), Color(0xFF312E81)]),
  ChatWallpaperPreset('dusk', [Color(0xFF7C3AED), Color(0xFFDB2777)]),
  ChatWallpaperPreset('ocean', [Color(0xFF0EA5E9), Color(0xFF1E3A8A)]),
  ChatWallpaperPreset('forest', [Color(0xFF34D399), Color(0xFF065F46)]),
  ChatWallpaperPreset('ember', [Color(0xFFF97316), Color(0xFF9A3412)]),
  ChatWallpaperPreset('graphite', [Color(0xFF334155), Color(0xFF0B1120)]),
];

ChatWallpaperPreset? chatWallpaperPresetById(String id) {
  for (final preset in chatWallpaperPresets) {
    if (preset.id == id) return preset;
  }
  return null;
}
