import 'package:flutter/material.dart';

import '../../../shared/widgets/video_preview.dart';
import '../../../shared/widgets/video_source.dart';
import '../../attachments/widgets/attachment_gate.dart';
import '../chat-timeline/attachment_image_tile.dart';
import '../data/models/chat_models.dart';
import 'shared_media_video_cell.dart';

/// One square cell in the shared-media strip and grid.
///
/// Pictures reuse the timeline's own tile, so a photo carries the same
/// download gate, the same locked placeholder and the same zoom viewer it has
/// in the conversation — the grid is a second way in, not a second renderer.
///
/// Video deliberately draws a plate rather than a frame: a poster per cell
/// means a decoder per cell, and a screenful of them drains the MediaCodec
/// pool. Tapping opens the real player, which is the one place a decoder is
/// worth holding.
class SharedMediaThumb extends StatelessWidget {
  const SharedMediaThumb({
    super.key,
    required this.attachment,
    required this.gallery,
    required this.size,
  });

  final ChatMessageAttachment attachment;

  /// Every image on this screen, so the viewer can swipe past the tapped one.
  /// Videos are not in it — they open their own player.
  final List<ChatMessageAttachment> gallery;
  final double size;

  static final BorderRadius _radius = BorderRadius.circular(6);

  @override
  Widget build(BuildContext context) {
    if (attachment.isImage) {
      final index = gallery.indexOf(attachment);
      return SizedBox(
        width: size,
        height: size,
        child: AttachmentImageTile(
          attachment: attachment,
          gallery: gallery,
          index: index < 0 ? 0 : index,
          maxHeight: size,
          maxWidth: size,
          grid: true,
          radius: _radius,
        ),
      );
    }
    return AttachmentGate(
      attachment: attachment,
      height: size,
      width: size,
      shape: _radius,
      showSize: false,
      ready: (context, handle) => SharedMediaVideoCell(
        localPath: handle.localPath!,
        size: size,
        radius: _radius,
        onTap: () => showVideoPreview(
          context,
          source: VideoSource.file(handle.localPath!),
          fileName: attachment.fileName,
        ),
      ),
    );
  }
}
