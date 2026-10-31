import 'package:flutter/material.dart';

import 'chat_wallpaper.dart';
import 'chat_wallpaper_background.dart';

/// A miniature conversation over the candidate wallpaper.
///
/// The reference app previews with two bubbles rather than a bare swatch,
/// because the only question that matters is whether text stays readable on it
/// — a colour chip cannot answer that.
class ChatWallpaperPreview extends StatelessWidget {
  const ChatWallpaperPreview({super.key, required this.wallpaper});

  final ChatWallpaper wallpaper;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 190,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (wallpaper.isSet)
              ChatWallpaperPaint(wallpaper: wallpaper)
            else
              ColoredBox(color: colors.surfaceContainerLow),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Bubble(
                    text: 'How does this look?',
                    background: colors.surfaceContainerHighest,
                    foreground: colors.onSurface,
                    alignment: Alignment.centerLeft,
                  ),
                  const SizedBox(height: 8),
                  _Bubble(
                    text: 'Looks good to me',
                    background: colors.primary,
                    foreground: colors.onPrimary,
                    alignment: Alignment.centerRight,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.text,
    required this.background,
    required this.foreground,
    required this.alignment,
  });

  final String text;
  final Color background;
  final Color foreground;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Text(
            text,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: foreground),
          ),
        ),
      ),
    );
  }
}
