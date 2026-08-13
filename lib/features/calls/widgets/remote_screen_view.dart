import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class RemoteScreenView extends StatefulWidget {
  const RemoteScreenView({required this.stream, super.key});

  final MediaStream stream;

  @override
  State<RemoteScreenView> createState() => _RemoteScreenViewState();
}

class _RemoteScreenViewState extends State<RemoteScreenView> {
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
  void didUpdateWidget(covariant RemoteScreenView oldWidget) {
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
    if (!_ready) return const Center(child: CircularProgressIndicator());
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: ColoredBox(
        color: Colors.black,
        child: RTCVideoView(
          _renderer,
          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
        ),
      ),
    );
  }
}
