import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/network_video_player.dart';
import '../../attachments/widgets/attachment_gate.dart';
import '../data/models/chat_models.dart';
import 'media-preview/chat_media_preview_meta.dart';
import 'media_frame.dart';
import 'media_frame_lock.dart';
import 'bubble_metrics.dart';

/// A video in a bubble, held to the same bounds as a photo — the reference app
/// sizes both off `media_bubble_*`, so a mixed album does not step in and out.
///
/// The frame is reserved in every state and taken from the poster's measured
/// shape when that was known at mount (see [MediaFrameLock]); the poster, the
/// loading placeholder and the live fallback all draw inside it.
class AttachmentVideoTile extends ConsumerStatefulWidget {
  const AttachmentVideoTile({
    super.key,
    required this.attachment,
    this.preview,
    this.inset = true,
    this.captioned = false,
  });

  final ChatMessageAttachment attachment;
  final ChatMediaPreviewMeta? preview;

  /// Caption / quoted clips keep an 8dp gap above. Media-only fills the bubble.
  final bool inset;

  /// Text under the clip: the reference app's wider floor, so the caption is
  /// not squeezed under a narrow portrait video.
  final bool captioned;

  @override
  ConsumerState<AttachmentVideoTile> createState() =>
      _AttachmentVideoTileState();
}

class _AttachmentVideoTileState extends ConsumerState<AttachmentVideoTile>
    with MediaFrameLock {
  @override
  ChatMessageAttachment get framedAttachment => widget.attachment;

  @override
  Widget build(BuildContext context) {
    final box = soloMediaSize(
      lockedDimensions,
      maxWidth: BubbleMetrics.mediaMaxWidth,
      minWidth: widget.captioned ? BubbleMetrics.mediaMinWidthWithCaption : 0,
    );
    return Padding(
      padding: EdgeInsets.only(top: widget.inset ? 8 : 0),
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: box.width, maxWidth: box.width),
        child: AttachmentGate(
          attachment: widget.attachment,
          reserveSpace: true,
          height: box.height,
          width: box.width,
          ready: (_, handle) => NetworkVideoPlayer(
            source: VideoSource.file(handle.localPath!),
            fileName: widget.attachment.fileName,
            detail: widget.preview?.detail,
            caption: widget.preview?.caption,
            maxHeight: BubbleMetrics.mediaMaxHeight,
            borderRadius: widget.inset ? 8 : 0,
          ),
        ),
      ),
    );
  }
}
