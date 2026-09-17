import 'package:flutter/material.dart';

import 'call_top_bar.dart' show callTextShadow;

/// A round call control. Photo-overlay surfaces keep their existing style;
/// the caller's themed surface opts into ColorScheme colours.
class CallControlButton extends StatelessWidget {
  const CallControlButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.label,
    this.selected = false,
    this.themeAware = false,
    this.background,
    this.foreground,
    this.size = 56,
    this.iconSize = 26,
  });

  /// The larger 78dp size Signal gives Answer and Decline, where the button is
  /// the only thing on screen worth touching.
  const CallControlButton.large({
    super.key,
    required this.icon,
    required this.onPressed,
    this.label,
    this.background,
    this.foreground,
  }) : themeAware = false,
       selected = false,
       size = 78,
       iconSize = 32;

  final IconData icon;
  final VoidCallback? onPressed;
  final String? label;
  final bool selected;
  final bool themeAware;
  final Color? background;
  final Color? foreground;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final bg =
        background ??
        (themeAware
            ? (selected
                  ? colors.primaryContainer
                  : colors.surfaceContainerHighest)
            : (selected ? Colors.white : Colors.white.withValues(alpha: 0.18)));
    final fg =
        foreground ??
        (themeAware
            ? (selected ? colors.onPrimaryContainer : colors.onSurface)
            : (selected ? Colors.black : Colors.white));
    final enabled = onPressed != null;

    return Semantics(
      button: true,
      enabled: enabled,
      toggled: selected,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Opacity(
            opacity: enabled ? 1 : 0.45,
            child: Material(
              color: bg,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onPressed,
                child: SizedBox(
                  width: size,
                  height: size,
                  child: Icon(icon, size: iconSize, color: fg),
                ),
              ),
            ),
          ),
          if (label != null) ...[
            const SizedBox(height: 8),
            Text(
              label!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: themeAware ? colors.onSurface : Colors.white,
                shadows: themeAware ? null : callTextShadow,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
