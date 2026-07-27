import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

/// Opens fullscreen video with autoplay + sound on.
Future<void> showVideoPreview(BuildContext context, {required String url}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.96),
    builder: (_) => _FullscreenVideoDialog(url: url),
  );
}

/// Inline preview — tap opens fullscreen (sound auto-on there).
class NetworkVideoPlayer extends StatefulWidget {
  const NetworkVideoPlayer({
    super.key,
    required this.url,
    this.maxHeight = 288,
    this.borderRadius = 8,
    this.autoPlay = false,
  });

  final String url;
  final double maxHeight;
  final double borderRadius;

  /// Unused for inline; kept for call-site compatibility.
  final bool autoPlay;

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
    if (oldWidget.url != widget.url) {
      _disposeController();
      _ready = false;
      _failed = false;
      _init();
    }
  }

  Future<void> _init() async {
    final controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
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
    await showVideoPreview(context, url: widget.url);
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

class _FullscreenVideoDialog extends StatefulWidget {
  const _FullscreenVideoDialog({required this.url});

  final String url;

  @override
  State<_FullscreenVideoDialog> createState() => _FullscreenVideoDialogState();
}

class _FullscreenVideoDialogState extends State<_FullscreenVideoDialog> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _failed = false;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _init();
  }

  Future<void> _init() async {
    final controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller = controller;
    try {
      await controller.initialize();
      await controller.setPlaybackSpeed(1.0);
      await controller.setVolume(1); // sound on
      await controller.setLooping(true);
      await controller.play();
      if (!mounted) return;
      setState(() => _ready = true);
      controller.addListener(() {
        if (mounted) setState(() {});
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlay() {
    final c = _controller;
    if (c == null || !_ready) return;
    if (c.value.isPlaying) {
      c.pause();
    } else {
      c.play();
    }
    setState(() => _showControls = true);
  }

  void _toggleMute() {
    final c = _controller;
    if (c == null || !_ready) return;
    final muted = c.value.volume <= 0.01;
    c.setVolume(muted ? 1 : 0);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = _controller;
    final muted = c != null && c.value.volume <= 0.01;

    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_failed)
              const Center(
                child: Icon(
                  Icons.videocam_off_outlined,
                  color: Colors.white54,
                  size: 48,
                ),
              )
            else if (!_ready || c == null)
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            else
              GestureDetector(
                onTap: () => setState(() => _showControls = !_showControls),
                child: Center(
                  child: AspectRatio(
                    aspectRatio: c.value.aspectRatio == 0
                        ? 16 / 9
                        : c.value.aspectRatio,
                    child: VideoPlayer(c),
                  ),
                ),
              ),
            Positioned(
              top: 4,
              left: 4,
              right: 4,
              child: AnimatedOpacity(
                opacity: _showControls ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    if (_ready)
                      IconButton(
                        onPressed: _toggleMute,
                        icon: Icon(
                          muted
                              ? Icons.volume_off_rounded
                              : Icons.volume_up_rounded,
                          color: Colors.white,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (_ready && c != null)
              Center(
                child: AnimatedOpacity(
                  opacity: _showControls || !c.value.isPlaying ? 1 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: IconButton(
                    onPressed: _togglePlay,
                    iconSize: 56,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                    ),
                    icon: Icon(
                      c.value.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            if (_ready && c != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: AnimatedOpacity(
                  opacity: _showControls || !c.value.isPlaying ? 1 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: ColoredBox(
                    color: Colors.black54,
                    child: VideoProgressIndicator(
                      c,
                      allowScrubbing: true,
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
                      colors: VideoProgressColors(
                        playedColor: scheme.primary,
                        bufferedColor: Colors.white38,
                        backgroundColor: Colors.white24,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Compact square thumb for pending-attachment strips.
class VideoPendingThumb extends StatelessWidget {
  const VideoPendingThumb({
    super.key,
    required this.placeholderColor,
    this.size = 72,
  });

  final Color placeholderColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: placeholderColor,
      child: SizedBox(
        width: size,
        height: size,
        child: const Center(
          child: Icon(Icons.play_circle_outline_rounded, size: 32),
        ),
      ),
    );
  }
}
