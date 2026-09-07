import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'call_video_view.dart';

/// Our own camera as a thumbnail in the corner, with the flip button on it —
/// where Signal and every dialler put it, so the control sits on the thing
/// it changes rather than in the crowded row at the bottom.
class LocalCameraPreview extends StatelessWidget {
  const LocalCameraPreview({
    super.key,
    required this.stream,
    required this.mirror,
    required this.onSwitchCamera,
  });

  final MediaStream stream;
  final bool mirror;
  final VoidCallback onSwitchCamera;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 108,
      height: 160,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CallVideoView(stream: stream, mirror: mirror),
            Positioned(
              right: 6,
              bottom: 6,
              child: Material(
                color: Colors.black.withValues(alpha: 0.45),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onSwitchCamera,
                  child: const Padding(
                    padding: EdgeInsets.all(7),
                    child: Icon(
                      Icons.cameraswitch_rounded,
                      size: 18,
                      color: Colors.white,
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
