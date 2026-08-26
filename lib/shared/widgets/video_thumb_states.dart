import 'package:flutter/material.dart';

/// The two non-playing states of an inline video: a controller that failed to
/// open, and one still opening. Both hold the same shape the player will take
/// so a ready video swaps in without shoving the timeline around.
class VideoThumbPlaceholder extends StatelessWidget {
  const VideoThumbPlaceholder({
    super.key,
    required this.height,
    required this.borderRadius,
    required this.child,
  });

  const VideoThumbPlaceholder.failed({super.key, required this.borderRadius})
    : height = 160,
      child = const Icon(Icons.videocam_off_outlined, size: 36);

  const VideoThumbPlaceholder.loading({
    super.key,
    required this.height,
    required this.borderRadius,
  }) : child = const SizedBox(
         width: 28,
         height: 28,
         child: CircularProgressIndicator(strokeWidth: 2),
       );

  final double height;
  final double borderRadius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: child,
    );
  }
}

/// The "Tap for fullscreen" hint pinned to the corner of an inline video.
class VideoFullscreenHint extends StatelessWidget {
  const VideoFullscreenHint({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.fullscreen_rounded, color: Colors.white, size: 16),
            SizedBox(width: 4),
            Text(
              'Tap for fullscreen',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
