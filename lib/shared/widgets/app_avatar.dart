import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../text/display_name.dart';
import 'avatar_cache.dart';

/// Homepage-style rounded-square avatar (radius 8 — not circle).
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    required this.size,
    this.url,
    this.name,
    this.fallback,
    this.backgroundColor,
    this.border,
    this.letterStyle,
  });

  static const double radius = 8;

  /// Google CDN often rejects bare Flutter requests; browser UA fixes decode.
  static const _headers = {
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
  };

  final double size;
  final String? url;
  final String? name;
  final Widget? fallback;
  final Color? backgroundColor;
  final Border? border;
  final TextStyle? letterStyle;

  String? get _safeUrl {
    final raw = url?.trim();
    if (raw == null || raw.isEmpty) return null;
    // Google size suffix → force a small JPEG-friendly size.
    if (raw.contains('googleusercontent.com')) {
      return raw.replaceFirst(RegExp(r'=s\d+-c'), '=s128-c');
    }
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // `name[0]` splits a surrogate pair, so a name opening with an emoji drew
    // a tofu box. [displayNameInitial] finds the first readable letter instead,
    // and returns null when a name has none at all.
    final letter = displayNameInitial(name) ?? '?';
    final bg = backgroundColor ?? colors.surfaceContainerHighest;
    final letterWidget =
        fallback ??
        Text(
          letter,
          style:
              letterStyle ??
              TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: size * 0.38,
                color: colors.onSurface,
              ),
        );
    final placeholder = ColoredBox(
      color: bg,
      child: Center(child: letterWidget),
    );
    final src = _safeUrl;
    // Decode at the size drawn, not the upload's: a group photo is often a
    // full camera frame, and decoding that for a 48dp tile is most of the
    // wait on a cold start. No fade — a picture read off disk should simply
    // be there, not dissolve in over half a second. Width only (both would
    // squash the aspect), doubled so a landscape photo cropped to the square
    // still has its full height in pixels.
    final px = (size * MediaQuery.devicePixelRatioOf(context) * 2).round();

    final inner = src == null
        ? placeholder
        : CachedNetworkImage(
            imageUrl: src,
            cacheManager: AvatarCache.instance,
            fit: BoxFit.cover,
            httpHeaders: _headers,
            memCacheWidth: px,
            fadeInDuration: Duration.zero,
            fadeOutDuration: Duration.zero,
            placeholder: (_, _) => placeholder,
            errorWidget: (_, _, _) => placeholder,
          );

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: border,
      ),
      clipBehavior: Clip.antiAlias,
      child: inner,
    );
  }
}
