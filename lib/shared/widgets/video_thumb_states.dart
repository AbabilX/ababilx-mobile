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

/// Signal's play / pause affordance: a light disc over the frame.
class VideoPlayBadge extends StatelessWidget {
  const VideoPlayBadge({super.key, this.size = 48, this.playing = false});

  final double size;

  /// Pause glyph while the video is running. Posters always leave this false.
  final bool playing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Icon(
        playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
        color: Colors.black87,
        size: size * 0.62,
      ),
    );
  }
}

/// Running time, bottom-left of a video tile. Signal shows it before you open
/// anything, which is how you decide whether to open it at all.
class VideoDurationBadge extends StatelessWidget {
  const VideoDurationBadge({super.key, required this.duration});

  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          formatVideoDuration(duration),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// `m:ss`, or `h:mm:ss` once there is an hour to show. Minutes are never
/// zero-padded on their own — `0:07`, not `00:07`.
String formatVideoDuration(Duration duration) {
  final seconds = duration.inSeconds.clamp(0, 359999);
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final rest = (seconds % 60).toString().padLeft(2, '0');
  if (hours > 0) return '$hours:${minutes.toString().padLeft(2, '0')}:$rest';
  return '$minutes:$rest';
}

/// Signal's remaining label: `–1:23`. Never negative.
String formatVideoRemaining(Duration position, Duration duration) {
  final left = duration - position;
  return '–${formatVideoDuration(left.isNegative ? Duration.zero : left)}';
}
