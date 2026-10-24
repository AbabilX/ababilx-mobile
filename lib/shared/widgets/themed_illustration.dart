import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// An unDraw illustration drawn in the app's own colors. Their files use a
/// fixed near-black outline, white screens and light grays, which vanish or
/// glare on a dark theme, so each fill is swapped for a theme color before
/// drawing. Skin tones and anything unlisted stay as drawn.
class ThemedIllustration extends StatelessWidget {
  const ThemedIllustration(this.asset, {super.key, this.height = 160});

  final String asset;
  final double height;

  static final _cache = <String, Future<String>>{};

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: height,
      child: FutureBuilder<String>(
        future: _cache.putIfAbsent(asset, () => rootBundle.loadString(asset)),
        builder: (_, snap) {
          final raw = snap.data;
          if (raw == null) return const SizedBox.shrink();
          return SvgPicture.string(themedSvg(raw, scheme), height: height);
        },
      ),
    );
  }
}

String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

/// Every `fill="#…"` mapped to the scheme: ink → onSurface, the accent
/// (unDraw's pure black) → primary, white → surface, light grays → the
/// container shades.
String themedSvg(String raw, ColorScheme scheme) {
  final map = {
    '#090814': _hex(scheme.onSurface),
    '#2f2e41': _hex(scheme.onSurface),
    '#3f3d56': _hex(scheme.onSurfaceVariant),
    '#000000': _hex(scheme.primary),
    '#fff': _hex(scheme.surface),
    '#ffffff': _hex(scheme.surface),
    '#f1f1f1': _hex(scheme.surfaceContainerHigh),
    '#e5e5e5': _hex(scheme.surfaceContainerHighest),
    '#d6d6e3': _hex(scheme.outlineVariant),
    '#cbcbcb': _hex(scheme.outlineVariant),
    '#ccc': _hex(scheme.outlineVariant),
  };
  return raw.replaceAllMapped(
    RegExp(r'fill="(#[0-9a-fA-F]{3,6})"'),
    (m) => 'fill="${map[m[1]!.toLowerCase()] ?? m[1]}"',
  );
}
