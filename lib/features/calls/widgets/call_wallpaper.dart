import 'package:flutter/material.dart';

/// Theme-aware Bangladeshi wallpaper behind audio-only 1:1 call UI.
///
/// Video / screen-share stages replace this with full-bleed media — never
/// paint wallpaper over a live remote stream.
class CallWallpaper extends StatelessWidget {
  const CallWallpaper({super.key});

  static const lightAsset = 'assets/images/wallpapers/call_light.jpg';
  static const darkAsset = 'assets/images/wallpapers/call_dark.jpg';

  static String assetFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkAsset : lightAsset;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Image.asset(
      assetFor(brightness),
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
    );
  }
}
