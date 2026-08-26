import 'package:flutter/material.dart';

import 'call_top_bar.dart' show callTextShadow;

/// A round call control, styled the way Signal styles them on a dark call
/// screen: a filled circle with an optional label underneath.
///
/// Colours are deliberately *not* taken from the app's ColorScheme. A call
/// screen is always dark — it sits on a blurred photo — so a light-theme
/// surface colour here would vanish. The three states Signal uses are:
///
///   idle     translucent white, white icon      (mic on, speaker off)
///   engaged  solid white, black icon            (muted, speaker on, sharing)
///   danger   red, white icon                    (hang up, decline)
class CallControlButton extends StatelessWidget {
  const CallControlButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.label,
    this.selected = false,
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
  }) : selected = false,
       size = 78,
       iconSize = 32;

  final IconData icon;
  final VoidCallback? onPressed;
  final String? label;
  final bool selected;
  final Color? background;
  final Color? foreground;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final bg =
        background ??
        (selected ? Colors.white : Colors.white.withValues(alpha: 0.18));
    final fg = foreground ?? (selected ? Colors.black : Colors.white);
    final enabled = onPressed != null;

    return Column(
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
              color: Colors.white,
              shadows: callTextShadow,
            ),
          ),
        ],
      ],
    );
  }
}
