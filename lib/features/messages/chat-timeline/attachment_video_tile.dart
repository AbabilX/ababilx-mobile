import 'package:flutter/material.dart';

import '../../../shared/widgets/network_video_player.dart';
import '../../attachments/widgets/attachment_gate.dart';
import '../data/models/chat_models.dart';
import 'media-preview/chat_media_preview_meta.dart';
import 'signal_bubble_metrics.dart';

/// A video in a bubble, held to the same bounds as a photo — Signal sizes both
/// off `media_bubble_*`, so a mixed album does not step in and out.
class AttachmentVideoTile extends StatelessWidget {
  const AttachmentVideoTile({
    super.key,
    required this.attachment,
    this.preview,
    this.inset = true,
  });

  final ChatMessageAttachment attachment;
  final ChatMediaPreviewMeta? preview;

  /// Caption / quoted clips keep an 8dp gap above. Media-only fills the bubble.
  final bool inset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: inset ? 8 : 0),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: SignalBubbleMetrics.mediaMaxWidth,
          maxWidth: SignalBubbleMetrics.mediaMaxWidth,
        ),
        child: AttachmentGate(
          attachment: attachment,
          reserveSpace: inset,
          height: SignalBubbleMetrics.mediaDefaultSize,
          width: SignalBubbleMetrics.mediaMaxWidth,
          ready: (_, handle) => NetworkVideoPlayer(
            source: VideoSource.file(handle.localPath!),
            fileName: attachment.fileName,
            detail: preview?.detail,
            caption: preview?.caption,
            maxHeight: SignalBubbleMetrics.mediaMaxHeight,
            borderRadius: inset ? 8 : 0,
          ),
        ),
      ),
    );
  }
}
