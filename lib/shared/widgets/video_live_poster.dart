import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'video_source.dart';
import 'video_thumb_states.dart';

/// The fallback poster: a real controller, initialised, muted and paused on
/// its first frame.
///
/// Only for sources the native extractor cannot answer for — a remote URL
/// (wall, CRM) and every non-Android build. It costs a decoder for as long as
/// it is mounted, which is exactly why chat does not use it.
class LiveVideoPoster extends StatefulWidget {
  const LiveVideoPoster({
    super.key,
    required this.source,
    required this.onTap,
    this.maxHeight = 288,
    this.borderRadius = 8,
  });

  final VideoSource source;
  final VoidCallback onTap;
  final double maxHeight;
  final double borderRadius;

  @override
  State<LiveVideoPoster> createState() => _LiveVideoPosterState();
}

class _LiveVideoPosterState extends State<LiveVideoPoster> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void didUpdateWidget(covariant LiveVideoPoster oldWidget) {
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
      await controller.setVolume(0);
      await controller.pause();
      // Seek a tiny bit so the first frame paints as the poster.
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

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (_failed) {
      return VideoThumbPlaceholder.failed(borderRadius: widget.borderRadius);
    }
    if (!_ready || c == null) {
      return VideoThumbPlaceholder.loading(
        height: widget.maxHeight * 0.55,
        borderRadius: widget.borderRadius,
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
              onTap: widget.onTap,
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
                  const ColoredBox(color: Color(0x22000000)),
                  const Center(child: VideoPlayBadge()),
                  if (c.value.duration > Duration.zero)
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: VideoDurationBadge(duration: c.value.duration),
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
