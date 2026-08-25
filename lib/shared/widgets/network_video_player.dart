import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'video_preview.dart';
import 'video_source.dart';

export 'video_source.dart';
export 'video_pending_thumb.dart';

class NetworkVideoPlayer extends StatefulWidget {
  const NetworkVideoPlayer({
    super.key,
    required this.source,
    this.maxHeight = 288,
    this.borderRadius = 8,
  });

  final VideoSource source;
  final double maxHeight;
  final double borderRadius;

  @override
  State<NetworkVideoPlayer> createState() => _NetworkVideoPlayerState();
}

class _NetworkVideoPlayerState extends State<NetworkVideoPlayer> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void didUpdateWidget(covariant NetworkVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source.key != widget.source.key) {
      _disposeController();
      _ready = false;
      _failed = false;
      _init();
    }
  }

  Future<void> _init() async {
    final controller = widget.source.controller();
    _controller = controller;
    try {
      await controller.initialize();
      await controller.setPlaybackSpeed(1.0);
      await controller.setVolume(0);
      await controller.setLooping(true);
      await controller.pause();
      // Seek a tiny bit so first frame paints as poster.
      if (controller.value.duration > Duration.zero) {
        await controller.seekTo(Duration.zero);
      }
      if (!mounted) return;
      setState(() => _ready = true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  void _disposeController() {
    _controller?.dispose();
    _controller = null;
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  Future<void> _openFullscreen() async {
    await showVideoPreview(context, source: widget.source);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = _controller;

    if (_failed) {
      return Container(
        height: 160,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(widget.borderRadius),
        ),
        child: const Icon(Icons.videocam_off_outlined, size: 36),
      );
    }

    if (!_ready || c == null) {
      return Container(
        height: widget.maxHeight * 0.55,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(widget.borderRadius),
        ),
        child: const SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    final size = c.value.size;
    final aspect = size.width <= 0 || size.height <= 0
        ? 16 / 9
        : size.width / size.height;

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: widget.maxHeight),
        child: AspectRatio(
          aspectRatio: aspect,
          child: Material(
            color: Colors.black,
            child: InkWell(
              onTap: _openFullscreen,
              child: Stack(
                alignment: Alignment.center,
                fit: StackFit.expand,
                children: [
                  FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: size.width,
                      height: size.height,
                      child: VideoPlayer(c),
                    ),
                  ),
                  const ColoredBox(color: Color(0x33000000)),
                  IconButton(
                    onPressed: _openFullscreen,
                    iconSize: 52,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                    ),
                    icon: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                    ),
                  ),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.fullscreen_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
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
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
