import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../media/video_thumbnail.dart';
import 'video_fullscreen_controls.dart';
import 'video_fullscreen_top_bar.dart';
import 'video_source.dart';
import 'video_thumb_states.dart';

/// The viewer a tapped video opens into.
///
/// Chrome (top bar, scrubber) fades out while the video plays and comes back
/// on a tap, the way every player does. It does **not** loop: a video that has
/// run out should stop and offer its play button, not start over behind a
/// viewer who has already looked away.
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
  bool _screenHeld = false;
  bool _muted = false;
  Timer? _hideTimer;

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
      await controller.setVolume(1);
      await controller.play();
      if (!mounted) return;
      controller.addListener(_onPlaybackChanged);
      setState(() => _ready = true);
      _scheduleHide();
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  /// The only thing the viewer itself needs off the tick: whether the screen
  /// is still earning its wake lock. Everything that shows the position
  /// listens to the controller directly.
  void _onPlaybackChanged() {
    final playing = _controller?.value.isPlaying ?? false;
    if (playing == _screenHeld) return;
    _screenHeld = playing;
    VideoThumbnails.keepScreenOn(playing);
    if (!playing && mounted) _revealControls();
  }

  void _revealControls() {
    _hideTimer?.cancel();
    if (!_showControls) setState(() => _showControls = true);
    _scheduleHide();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (!(_controller?.value.isPlaying ?? false)) return;
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _toggleChrome() {
    _hideTimer?.cancel();
    setState(() => _showControls = !_showControls);
    if (_showControls) _scheduleHide();
  }

  void _toggleMute() {
    final c = _controller;
    if (c == null || !_ready) return;
    // Held in the state rather than read back off the controller: the viewer
    // no longer rebuilds on every tick, so nothing else would notice.
    final next = !_muted;
    c.setVolume(next ? 0 : 1);
    setState(() => _muted = next);
    _revealControls();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    if (_screenHeld) VideoThumbnails.keepScreenOn(false);
    _controller?.removeListener(_onPlaybackChanged);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      // Scaffold so a save confirmation is drawn over the video rather than on
      // the screen hidden behind this dialog.
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
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
                onTap: _toggleChrome,
                // The video rarely fills the screen; a tap on the letterbox
                // has to bring the chrome back too.
                behavior: HitTestBehavior.opaque,
                child: Center(
                  child: AspectRatio(
                    aspectRatio: c.value.aspectRatio == 0
                        ? 16 / 9
                        : c.value.aspectRatio,
                    child: VideoPlayer(c),
                  ),
                ),
              ),
            if (_ready && c != null) _centreButton(c),
            _chrome(
              alignment: Alignment.topCenter,
              child: SafeArea(
                bottom: false,
                child: VideoFullscreenTopBar(
                  source: widget.source,
                  fileName: widget.fileName,
                  ready: _ready,
                  muted: _muted,
                  onToggleMute: _toggleMute,
                ),
              ),
            ),
            if (_ready && c != null)
              _chrome(
                alignment: Alignment.bottomCenter,
                child: VideoFullscreenControls(
                  controller: c,
                  onInteract: _revealControls,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Only while paused: a playing video should be the whole screen.
  Widget _centreButton(VideoPlayerController c) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: c,
      builder: (context, value, _) {
        if (value.isPlaying) return const SizedBox.shrink();
        return Center(
          child: GestureDetector(
            onTap: () {
              c.play();
              _scheduleHide();
            },
            child: const VideoPlayBadge(size: 64),
          ),
        );
      },
    );
  }

  Widget _chrome({required Alignment alignment, required Widget child}) {
    return Align(
      alignment: alignment,
      child: IgnorePointer(
        ignoring: !_showControls,
        child: AnimatedOpacity(
          opacity: _showControls ? 1 : 0,
          duration: const Duration(milliseconds: 180),
          child: child,
        ),
      ),
    );
  }
}
