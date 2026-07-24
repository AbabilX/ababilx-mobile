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

  final double size;
  final String? url;
  final String? name;
  final Widget? fallback;
  final Color? backgroundColor;
  final Border? border;
  final TextStyle? letterStyle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final letter =
        (name != null && name!.isNotEmpty) ? name![0].toUpperCase() : '?';
    final bg = backgroundColor ?? colors.surfaceContainerHighest;

    final inner = url != null && url!.isNotEmpty
        ? CachedNetworkImage(imageUrl: url!, fit: BoxFit.cover)
        : ColoredBox(
            color: bg,
            child: Center(
              child: fallback ??
                  Text(
                    letter,
                    style: letterStyle ??
                        TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: size * 0.38,
                          color: colors.onSurface,
                        ),
                  ),
            ),
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
