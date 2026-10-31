import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'preview_icon.dart';
import 'video_thumb_states.dart';

/// Elapsed · slider · remaining. Listens on its own so the video surface is
/// not rebuilt on every position tick.
///
/// Scrub pauses, then resumes if it was playing — the reference app's TimeBar
/// rule.
class VideoFullscreenControls extends StatefulWidget {
  const VideoFullscreenControls({
    super.key,
    required this.controller,
    required this.onInteract,
    required this.onTogglePlay,
  });

  final VideoPlayerController controller;
  final VoidCallback onInteract;
  final VoidCallback onTogglePlay;

  @override
  State<VideoFullscreenControls> createState() =>
      _VideoFullscreenControlsState();
}

class _VideoFullscreenControlsState extends State<VideoFullscreenControls> {
  bool _wasPlaying = false;

  VideoPlayerController get _controller => widget.controller;

  void _seekFraction(double value, Duration duration) {
    final ms = (duration.inMilliseconds * value.clamp(0.0, 1.0)).round();
    _controller.seekTo(Duration(milliseconds: ms));
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: _controller,
      builder: (context, value, _) {
        final duration = value.duration;
        final hasDuration = duration > Duration.zero;
        final progress = !hasDuration
            ? 0.0
            : (value.position.inMilliseconds / duration.inMilliseconds).clamp(
                0.0,
                1.0,
              );
        return Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 12, 10),
          child: Row(
            children: [
              IconButton(
                tooltip: value.isPlaying ? 'Pause' : 'Play',
                onPressed: () {
                  widget.onInteract();
                  widget.onTogglePlay();
                },
                icon: PreviewIcon(
                  value.isPlaying ? PreviewIcons.pause : PreviewIcons.play,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              _TimeLabel(formatVideoDuration(value.position)),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 14,
                    ),
                    activeTrackColor: Colors.white,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: Colors.white,
                    overlayColor: Colors.white24,
                    trackShape: const RoundedRectSliderTrackShape(),
                  ),
                  child: Slider(
                    value: progress,
                    onChanged: hasDuration
                        ? (next) {
                            widget.onInteract();
                            _seekFraction(next, duration);
                          }
                        : null,
                    onChangeStart: hasDuration
                        ? (_) {
                            widget.onInteract();
                            _wasPlaying = value.isPlaying;
                            _controller.pause();
                          }
                        : null,
                    onChangeEnd: hasDuration
                        ? (next) {
                            _seekFraction(next, duration);
                            if (_wasPlaying) _controller.play();
                          }
                        : null,
                  ),
                ),
              ),
              _TimeLabel(formatVideoRemaining(value.position, duration)),
            ],
          ),
        );
      },
    );
  }
}

class _TimeLabel extends StatelessWidget {
  const _TimeLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
