import 'package:flutter/material.dart';

import 'media_preview_actions.dart';
import 'video_source.dart';

/// Close, mute and the overflow that holds Save/Share — the row that fades
/// with the rest of the video controls.
class VideoFullscreenTopBar extends StatelessWidget {
  const VideoFullscreenTopBar({
    super.key,
    required this.source,
    required this.fileName,
    required this.ready,
    required this.muted,
    required this.onToggleMute,
  });

  final VideoSource source;
  final String fileName;
  final bool ready;
  final bool muted;
  final VoidCallback onToggleMute;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded, color: Colors.white),
        ),
        const Spacer(),
        if (ready)
          IconButton(
            onPressed: onToggleMute,
            icon: Icon(
              muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              color: Colors.white,
            ),
          ),
        if (fileName.isNotEmpty)
          MediaPreviewOverflow(
            localPath: source.path,
            remoteUrl: source.url,
            fileName: fileName,
          ),
      ],
    );
  }
}
