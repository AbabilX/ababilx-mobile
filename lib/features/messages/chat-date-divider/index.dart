import 'package:flutter/material.dart';
import '../../../shared/text/latin_tracking.dart';

/// Signal's day marker: centred, small, and set on a chip once a wallpaper is
/// behind it so the label stays readable over a photo.
class ChatDateDivider extends StatelessWidget {
  const ChatDateDivider({
    super.key,
    required this.label,
    this.hasWallpaper = false,
  });

  final String label;
  final bool hasWallpaper;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Text(
      label.toUpperCase(),
      style: TextStyle(
        color: colors.onSurfaceVariant,
        fontSize: 12,
        letterSpacing: latinTracking(label, 0.4),
        fontWeight: FontWeight.w500,
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
      child: Center(
        child: hasWallpaper
            ? Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: text,
              )
            : text,
      ),
    );
  }
}
