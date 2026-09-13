import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'video_fit.dart';

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

  /// A person's camera, which wants to fill the box, rather than a screen,
  /// whose edges carry content and must be letterboxed whole.
  ///
  /// Filling is not unconditional: see [videoDisplaySize]. A camera whose
  /// orientation matches the box fills it; one that does not — a laptop
  /// calling a phone, which is most cross-device calls — is cropped only as
  /// far as Signal crops it and letterboxed for the rest.
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
    if (!widget.cover) {
      return _view(RTCVideoViewObjectFit.RTCVideoViewObjectFitContain);
    }
    // The renderer reports the frame size, and it changes mid-call — the peer
    // flips their camera, or rotates the phone — so the box is recomputed from
    // it rather than measured once.
    return ValueListenableBuilder<RTCVideoValue>(
      valueListenable: _renderer,
      builder: (context, value, _) {
        if (!value.renderVideo || value.width == 0 || value.height == 0) {
          return const ColoredBox(color: Colors.black);
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            final size = videoDisplaySize(
              constraints.biggest,
              value.aspectRatio,
            );
            return ColoredBox(
              color: Colors.black,
              child: Center(
                child: SizedBox(
                  width: size.width,
                  height: size.height,
                  child: _view(
                    RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _view(RTCVideoViewObjectFit fit) {
    return ColoredBox(
      color: Colors.black,
      child: RTCVideoView(_renderer, mirror: widget.mirror, objectFit: fit),
    );
  }
}
