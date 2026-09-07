import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// One WebRTC video stream drawn into a box.
///
/// Owns its renderer, which is the expensive part: a renderer per frame of
/// a rebuilding widget tree is what stalls a call, so the stream is swapped
/// on the same renderer in [didUpdateWidget] instead.
class CallVideoView extends StatefulWidget {
  const CallVideoView({
    super.key,
    required this.stream,
    this.cover = true,
    this.mirror = false,
  });

  final MediaStream stream;

  /// Fill the box (a person's camera) rather than letterbox it (a screen,
  /// where the edges carry content).
  final bool cover;

  /// A front camera preview reads as a mirror; the far side must never be.
  final bool mirror;

  @override
  State<CallVideoView> createState() => _CallVideoViewState();
}

class _CallVideoViewState extends State<CallVideoView> {
  final RTCVideoRenderer _renderer = RTCVideoRenderer();
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _renderer.initialize();
    if (!mounted) {
      await _renderer.dispose();
      return;
    }
    _renderer.srcObject = widget.stream;
    setState(() => _ready = true);
  }

  @override
  void didUpdateWidget(covariant CallVideoView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_ready && oldWidget.stream != widget.stream) {
      _renderer.srcObject = widget.stream;
    }
  }

  @override
  void dispose() {
    _renderer.srcObject = null;
    _renderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const ColoredBox(color: Colors.black);
    return ColoredBox(
      color: Colors.black,
      child: RTCVideoView(
        _renderer,
        mirror: widget.mirror,
        objectFit: widget.cover
            ? RTCVideoViewObjectFit.RTCVideoViewObjectFitCover
            : RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
      ),
    );
  }
}
