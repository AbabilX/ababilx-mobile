import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

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
    final letter = (name != null && name!.isNotEmpty)
        ? name![0].toUpperCase()
        : '?';
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

    final inner = src == null
        ? placeholder
        : CachedNetworkImage(
            imageUrl: src,
            fit: BoxFit.cover,
            httpHeaders: _headers,
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
