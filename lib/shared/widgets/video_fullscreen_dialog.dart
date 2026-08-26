import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import 'video_fullscreen_top_bar.dart';
import 'video_source.dart';

class FullscreenVideoDialog extends StatefulWidget {
  const FullscreenVideoDialog({
    super.key,
    required this.source,
    this.fileName = '',
  });

  final VideoSource source;

  /// Empty means the caller has no name for these bytes, so the viewer offers
  /// no Save/Share — a file saved as "null.mp4" is worse than no button.
  final String fileName;

  @override
  State<FullscreenVideoDialog> createState() => FullscreenVideoDialogState();
}

class FullscreenVideoDialogState extends State<FullscreenVideoDialog> {
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
    final controller = widget.source.controller();
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
      // Scaffold so a save confirmation is drawn over the video rather than on
      // the screen hidden behind this dialog.
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
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
                  child: VideoFullscreenTopBar(
                    source: widget.source,
                    fileName: widget.fileName,
                    ready: _ready,
                    muted: muted,
                    onToggleMute: _toggleMute,
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
      ),
    );
  }
}
