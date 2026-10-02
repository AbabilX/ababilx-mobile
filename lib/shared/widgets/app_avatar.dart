import 'package:flutter/material.dart';

import '../avatar-store/avatar_picture.dart';
import '../text/display_name.dart';

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
    this.owner,
  });

  static const double radius = 8;

  final double size;
  final String? url;
  final String? name;
  final Widget? fallback;
  final Color? backgroundColor;
  final Border? border;
  final TextStyle? letterStyle;

  /// Whose picture this is — `user:<id>` or `conv:<id>`. With it, a changed
  /// photo keeps showing the old one until the new one is on the phone.
  final String? owner;

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
    final src = url?.trim() ?? '';
    // Drawn from the phone's own copy (Signal's AvatarHelper, WhatsApp's
    // contact thumbnails): found without waiting, already shrunk to the size
    // shown, so a face the phone has is simply there — no lookup, no fade.
    final inner = src.isEmpty
        ? placeholder
        : AvatarPicture(url: src, owner: owner, placeholder: placeholder);

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
