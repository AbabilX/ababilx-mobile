import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../shared/media/video_thumbnail.dart';
import '../chat_icon.dart';

/// The 48dp picture on the camera flow's "Send to" bar.
///
/// The in-app camera records video too, and a video's bytes are not an image:
/// `Image.memory` on them drew "Exception: Invalid image data" in the bar. A
/// video shows its native poster frame ([VideoThumbnails], read from the
/// file the camera wrote) under a play badge; anything that still cannot be
/// decoded shows a plain glyph instead of an error.
class CameraSendThumb extends StatelessWidget {
  const CameraSendThumb({
    super.key,
    required this.bytes,
    this.isVideo = false,
    this.path,
  });

  final Uint8List bytes;
  final bool isVideo;

  /// The camera's own file, which the video poster is extracted from.
  final String? path;

  static const double _size = 48;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox.square(
        dimension: _size,
        child: isVideo ? _video(context) : _photo(context),
      ),
    );
  }

  Widget _photo(BuildContext context) => Image.memory(
    bytes,
    width: _size,
    height: _size,
    fit: BoxFit.cover,
    errorBuilder: (_, _, _) => _glyph(context, HugeIcons.strokeRoundedImage01),
  );

  Widget _video(BuildContext context) {
    final source = path;
    final poster = source == null
        ? Future<VideoThumb?>.value()
        : VideoThumbnails.forFile(source, maxPx: 160);
    return FutureBuilder<VideoThumb?>(
      future: poster,
      initialData: source == null ? null : VideoThumbnails.peek(source),
      builder: (context, snapshot) {
        final frame = snapshot.data;
        if (frame == null) {
          return _glyph(context, HugeIcons.strokeRoundedVideo01);
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            Image.file(File(frame.path), fit: BoxFit.cover),
            const Center(
              child: ChatIcon(
                HugeIcons.strokeRoundedPlay,
                size: 20,
                color: Colors.white,
                strokeWidth: 1.8,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _glyph(BuildContext context, List<List<dynamic>> icon) {
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.surfaceContainerHighest,
      child: Center(
        child: ChatIcon(icon, size: 22, color: colors.onSurfaceVariant),
      ),
    );
  }
}
