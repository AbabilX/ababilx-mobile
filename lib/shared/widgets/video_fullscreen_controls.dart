import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'video_thumb_states.dart';

/// The scrubber row: play/pause, elapsed, seek bar, total.
///
/// Listens to the controller on its own so the video surface above it is not
/// rebuilt on every position tick — that used to rebuild the whole viewer
/// several times a second.
class VideoFullscreenControls extends StatelessWidget {
  const VideoFullscreenControls({
    super.key,
    required this.controller,
    required this.onInteract,
  });

  final VideoPlayerController controller;

  /// Any touch here counts as "still watching", so the chrome does not fade
  /// out from under a finger on the seek bar.
  final VoidCallback onInteract;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: Colors.black54,
      child: SafeArea(
        top: false,
        child: ValueListenableBuilder<VideoPlayerValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 12, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      onInteract();
                      value.isPlaying ? controller.pause() : controller.play();
                    },
                    icon: Icon(
                      value.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    formatVideoDuration(value.position),
                    style: _timeStyle,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Listener(
                        onPointerDown: (_) => onInteract(),
                        child: VideoProgressIndicator(
                          controller,
                          allowScrubbing: true,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          colors: VideoProgressColors(
                            playedColor: scheme.primary,
                            bufferedColor: Colors.white38,
                            backgroundColor: Colors.white24,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Text(
                    formatVideoDuration(value.duration),
                    style: _timeStyle,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

const _timeStyle = TextStyle(
  color: Colors.white,
  fontSize: 12,
  fontFeatures: [FontFeature.tabularFigures()],
);
