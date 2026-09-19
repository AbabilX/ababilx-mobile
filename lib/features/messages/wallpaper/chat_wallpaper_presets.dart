import 'package:flutter/material.dart';

/// Both dewdrop / rainy paintings are anchored to this corner wherever they
/// are drawn — grid tile, preview and the chat itself.
///
/// A phone screen is much taller than either picture, so `cover` scales them
/// past the viewport and crops the overflow. Both were composed with their
/// subject low and to the left, so centring the crop cuts the flowers off and
/// leaves an empty sky.
const Alignment chatWallpaperArtAlignment = Alignment.bottomLeft;

/// Seamless doodle patterns (the mobile light/dark pair) tile from the centre
/// so the crop does not favour one edge of the repeating motif.
const Alignment chatWallpaperPatternAlignment = Alignment.center;

const String chatWallpaperMobileId = 'mobile';
const String chatWallpaperDewdropId = 'dewdrop';
const String chatWallpaperRainyPaddyId = 'rainy-paddy';

/// One of the built-in backgrounds.
@immutable
class ChatWallpaperPreset {
  const ChatWallpaperPreset(
    this.id,
    this.colors, {
    this.asset,
    this.darkAsset,
    this.darkSolid,
    this.alignment = chatWallpaperArtAlignment,
  });

  final String id;

  /// One colour paints flat; two or more paint as a diagonal gradient, which
  /// is how Signal's preset set is built.
  final List<Color> colors;

  /// A bundled painting. When set it is what actually shows and [colors] is
  /// only the ground under it, so a tile is never blank while the image
  /// decodes. Light theme (and dark theme when [darkAsset] is null) uses this.
  final String? asset;

  /// Optional dark-theme painting. When set, the chat switches between
  /// [asset] and this by [Brightness] instead of dimming the light picture.
  final String? darkAsset;

  /// Ground under [darkAsset] while it decodes. Falls back to [solid].
  final Color? darkSolid;

  /// Where [BoxFit.cover] anchors the crop. Paintings with a composed subject
  /// use [chatWallpaperArtAlignment]; repeating patterns use centre.
  final Alignment alignment;

  bool get isArt => asset != null;

  /// Whether this preset swaps art with the theme (not just dim overlay).
  bool get isThemePair => asset != null && darkAsset != null;

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

  Color groundFor(Brightness brightness) =>
      brightness == Brightness.dark && darkSolid != null ? darkSolid! : solid;

  /// The asset path that should paint for [brightness], or null for solids.
  String? assetFor(Brightness brightness) {
    if (asset == null) return null;
    if (brightness == Brightness.dark && darkAsset != null) return darkAsset;
    return asset;
  }
}

/// The built-in set. Theme-aware mobile art leads, then the older paintings,
/// then solids, then gradients, so the grid reads left-to-right from loud to
/// calm.
///
/// The mobile pair is the fresh-install global default (see
/// [ChatWallpaperStore.shipDefaultIfFreshInstall]). Upgrades and an explicit
/// "No wallpaper" choice stay plain.
const List<ChatWallpaperPreset> chatWallpaperPresets = [
  ChatWallpaperPreset(
    chatWallpaperMobileId,
    [Color(0xFFE6E2DA)],
    asset: 'assets/images/wallpapers/mobile_light.jpg',
    darkAsset: 'assets/images/wallpapers/mobile_dark.jpg',
    darkSolid: Color(0xFF1A3D2E),
    alignment: chatWallpaperPatternAlignment,
  ),
  ChatWallpaperPreset(chatWallpaperDewdropId, [
    Color(0xFF9CC77E),
  ], asset: 'assets/images/wallpapers/dewdrop_field.jpg'),
  ChatWallpaperPreset(chatWallpaperRainyPaddyId, [
    Color(0xFF4E6B4A),
  ], asset: 'assets/images/wallpapers/rainy_paddy.jpg'),
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
