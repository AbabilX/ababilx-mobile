import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../media/video_thumbnail.dart';
import 'image_preview_chrome.dart';
import 'image_preview_top_bar.dart';
import 'video_preview_footer.dart';
import 'video_source.dart';
import 'video_thumb_states.dart';

/// The viewer a tapped video opens into.
///
/// Chrome (toolbar, scrubber, capsule) fades out while the video plays and
/// comes back on a tap, the way every player does. It does **not** loop: a
/// video that has run out should stop and offer its play button, not start
/// over behind a viewer who has already looked away.
class FullscreenVideoDialog extends StatefulWidget {
  const FullscreenVideoDialog({
    super.key,
    required this.source,
    this.fileName = '',
    this.detail,
    this.caption,
  });

  final VideoSource source;

  /// Empty means the caller has no name for these bytes, so the viewer offers
  /// no Save/Share — a file saved as "null.mp4" is worse than no button.
  final String fileName;

  /// Second toolbar line — chat passes `You · 10:00 AM`.
  final String? detail;

  /// Plain body under the video. Null when the message is media-only.
  final String? caption;

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
  int _turns = 0;
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

  void _rotate() {
    setState(() => _turns = (_turns + 1) % 4);
    _revealControls();
  }

  void _togglePlay() {
    final c = _controller;
    if (c == null || !_ready) return;
    if (c.value.isPlaying) {
      c.pause();
      _revealControls();
      return;
    }
    final value = c.value;
    if (value.duration > Duration.zero && value.position >= value.duration) {
      c.seekTo(Duration.zero);
    }
    c.play();
    _scheduleHide();
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
      backgroundColor: ImagePreviewChrome.background,
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
                  child: RotatedBox(
                    quarterTurns: _turns,
                    child: AspectRatio(
                      aspectRatio: c.value.aspectRatio == 0
                          ? 16 / 9
                          : c.value.aspectRatio,
                      child: VideoPlayer(c),
                    ),
                  ),
                ),
              ),
            if (_ready && c != null) _centreButton(c),
            Align(
              alignment: Alignment.topCenter,
              child: ImagePreviewChrome.layer(
                visible: _showControls,
                child: ImagePreviewTopBar(
                  fileName: widget.fileName,
                  detail: widget.detail,
                ),
              ),
            ),
            if (_ready && c != null)
              Align(
                alignment: Alignment.bottomCenter,
                child: ImagePreviewChrome.layer(
                  visible: _showControls,
                  child: VideoPreviewFooter(
                    controller: c,
                    onInteract: _revealControls,
                    fileName: widget.fileName,
                    localPath: widget.source.path,
                    remoteUrl: widget.source.url,
                    caption: widget.caption,
                    muted: _muted,
                    onMute: _toggleMute,
                    onRotate: _rotate,
                    onTogglePlay: _togglePlay,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Play while paused; pause while chrome is up. A playing video with chrome
  /// hidden stays the whole screen.
  Widget _centreButton(VideoPlayerController c) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: c,
      builder: (context, value, _) {
        if (value.isPlaying && !_showControls) return const SizedBox.shrink();
        return Center(
          child: GestureDetector(
            onTap: _togglePlay,
            child: VideoPlayBadge(size: 72, playing: value.isPlaying),
          ),
        );
      },
    );
  }
}
