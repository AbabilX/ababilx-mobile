import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../shared/widgets/avatar_cache.dart';

/// The full-bleed backdrop behind every call surface.
///
/// Signal blurs the caller's own photo across the whole window and lays a
/// black scrim over it, so the screen is legibly dark whatever the photo is
/// and the person is still recognisable. `IncomingCallScreen` uses a heavier
/// scrim (0.4) than the connected screen (0.2) for exactly that reason: while
/// ringing, the text on top is the only thing that matters.
///
/// With no photo to blur we fall back to a dark theme-derived gradient rather
/// than flat black — the same shape, just without a subject.
class CallBackdrop extends StatelessWidget {
  const CallBackdrop({
    super.key,
    required this.avatarUrl,
    this.scrim = 0.4,
    this.themeAware = false,
    this.blurSigma = 32,
  });

  final String? avatarUrl;
  final double scrim;
  final bool themeAware;
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final url = avatarUrl?.trim();
    final hasPhoto = url != null && url.isNotEmpty;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (hasPhoto)
          ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: blurSigma,
              sigmaY: blurSigma,
              tileMode: TileMode.decal,
            ),
            child: CachedNetworkImage(
              cacheManager: AvatarCache.instance,
              imageUrl: url,
              fit: BoxFit.cover,
              placeholder: (_, _) =>
                  _Fallback(colors: colors, themeAware: themeAware),
              errorWidget: (_, _, _) =>
                  _Fallback(colors: colors, themeAware: themeAware),
            ),
          )
        else
          _Fallback(colors: colors, themeAware: themeAware),
        ColoredBox(
          color: themeAware
              ? colors.surface.withValues(alpha: 0.88)
              : Colors.black.withValues(alpha: scrim),
        ),
      ],
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.colors, this.themeAware = false});

  final ColorScheme colors;
  final bool themeAware;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.alphaBlend(
              colors.primary.withValues(alpha: 0.35),
              themeAware ? colors.surface : Colors.black,
            ),
            themeAware ? colors.surface : Colors.black,
          ],
        ),
      ),
    );
  }
}
