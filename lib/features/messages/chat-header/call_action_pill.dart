import 'dart:ui';

import 'package:flutter/material.dart';

/// Header call affordance: icon + label ("Talk" on DMs, "Meet" on groups)
/// instead of a bare glyph. Deliberately compact — the header uses a centred
/// title, and a wide trailing widget eats the name.
///
/// Frosted glass over the chat wallpaper — no solid container colour — so the
/// pill reads the same way as the shell nav chrome.
class CallActionPill extends StatelessWidget {
  const CallActionPill({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.highlighted = false,
    this.busy = false,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  /// Live call for this conversation — tints the pill with the primary colour.
  final bool highlighted;
  final bool busy;
  final int badgeCount;

  static const _radius = BorderRadius.all(Radius.circular(999));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final enabled = onTap != null && !busy;
    final dark = colors.brightness == Brightness.dark;

    // Blur is the fill; tint only enough for contrast / live-call state.
    final fill = highlighted
        ? colors.primary.withValues(alpha: dark ? 0.38 : 0.28)
        : colors.surface.withValues(alpha: dark ? 0.42 : 0.48);
    final foreground = highlighted ? colors.onPrimary : colors.onSurface;
    final opacity = enabled ? 1.0 : 0.45;

    final pill = Opacity(
      opacity: opacity,
      child: ClipRRect(
        borderRadius: _radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: fill,
              borderRadius: _radius,
              border: Border.all(
                color: colors.outlineVariant.withValues(alpha: 0.35),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (busy)
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: foreground,
                      ),
                    )
                  else
                    Icon(icon, size: 18, color: foreground),
                  const SizedBox(width: 7),
                  Text(
                    label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                  if (badgeCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: foreground.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$badgeCount',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: foreground,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        borderRadius: _radius,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: _radius,
          child: pill,
        ),
      ),
    );
  }
}
