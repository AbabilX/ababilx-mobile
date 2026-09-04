import 'package:flutter/material.dart';

import '../media/video_thumbnail.dart';
import 'video_live_poster.dart';
import 'video_poster_frame.dart';
import 'video_preview.dart';
import 'video_source.dart';
import 'video_thumb_states.dart';

export 'video_source.dart';
export 'video_pending_thumb.dart';

/// An inline video: poster now, player only once tapped.
///
/// Picks how to draw the poster. A downloaded file on Android gets a frame the
/// platform extracted once and cached — no decoder held, so a timeline of
/// videos costs nothing to scroll. Anything else (a remote URL on the wall,
/// any non-Android build) falls back to a live paused controller.
class NetworkVideoPlayer extends StatefulWidget {
  const NetworkVideoPlayer({
    super.key,
    required this.source,
    this.fileName = '',
    this.maxHeight = 288,
    this.borderRadius = 8,
  });

  final VideoSource source;

  /// Passed to the fullscreen viewer so it can offer Save/Share. Empty when
  /// the caller has no name for the file.
  final String fileName;
  final double maxHeight;
  final double borderRadius;

  @override
  State<NetworkVideoPlayer> createState() => _NetworkVideoPlayerState();
}

class _NetworkVideoPlayerState extends State<NetworkVideoPlayer> {
  late Future<VideoThumb?> _thumb;

  @override
  void initState() {
    super.initState();
    _thumb = _resolve();
  }

  @override
  void didUpdateWidget(covariant NetworkVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A download finishing under a mounted player swaps a URL for a path.
    if (oldWidget.source.key != widget.source.key) {
      setState(() => _thumb = _resolve());
    }
  }

  Future<VideoThumb?> _resolve() {
    final path = widget.source.path;
    if (!widget.source.isLocal || path == null) return Future.value(null);
    return VideoThumbnails.forFile(path);
  }

  Future<void> _openFullscreen() => showVideoPreview(
    context,
    source: widget.source,
    fileName: widget.fileName,
  );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<VideoThumb?>(
      future: _thumb,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return VideoThumbPlaceholder.loading(
            height: widget.maxHeight * 0.55,
            borderRadius: widget.borderRadius,
          );
        }
        final thumb = snapshot.data;
        if (thumb == null) {
          return LiveVideoPoster(
            source: widget.source,
            onTap: _openFullscreen,
            maxHeight: widget.maxHeight,
            borderRadius: widget.borderRadius,
          );
        }
        return VideoPosterFrame(
          thumb: thumb,
          onTap: _openFullscreen,
          maxHeight: widget.maxHeight,
          borderRadius: widget.borderRadius,
        );
      },
    );
  }
}
