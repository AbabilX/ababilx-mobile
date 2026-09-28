import 'package:flutter/material.dart';

/// One of the rounded-square actions under the avatar (Call / Mute / Search).
///
/// Signal draws these as a filled square with the label under it, not as an
/// icon button — the label is part of the control, so it is inside the tap
/// target rather than floating beside it.
class DetailsActionButton extends StatelessWidget {
  const DetailsActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final Widget icon;
  final String label;
  final VoidCallback? onTap;

  /// Muted / in-call state. The square stays the neutral surface — only the
  /// glyph takes the accent — so a toggle that is on still reads as on
  /// without a coloured block.
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final enabled = onTap != null;
    final background = colors.surfaceContainerHigh;
    final foreground = active ? colors.primary : colors.onSurface;

    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: background,
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: SizedBox(
                width: 68,
                height: 60,
                child: Center(
                  child: IconTheme.merge(
                    data: IconThemeData(color: foreground, size: 24),
                    child: icon,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: colors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
