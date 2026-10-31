import 'package:flutter/material.dart';
import '../../../shared/text/latin_tracking.dart';

/// The reference app's day marker: centred, small, and set on a chip once a
/// wallpaper is behind it so the label stays readable over a photo.
class ChatDateDivider extends StatelessWidget {
  const ChatDateDivider({
    super.key,
    required this.label,
    this.hasWallpaper = false,
    this.onTap,
  });

  final String label;
  final bool hasWallpaper;

  /// Opens the jump-to-date sheet.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: colors.onSurfaceVariant,
            fontSize: 12,
            letterSpacing: latinTracking(label, 0.4),
            fontWeight: FontWeight.w500,
          ),
        ),
        // Says the marker is tappable (jump to a date).
        if (onTap != null) ...[
          const SizedBox(width: 2),
          Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 16,
            color: colors.onSurfaceVariant,
          ),
        ],
      ],
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
      child: Center(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: _chip(colors, text),
          ),
        ),
      ),
    );
  }

  Widget _chip(ColorScheme colors, Widget text) {
    return hasWallpaper
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: text,
          )
        : text;
  }
}
