import 'package:flutter/material.dart';

import '../../../shared/widgets/network_video_player.dart';
import '../../attachments/widgets/attachment_gate.dart';
import '../data/models/chat_models.dart';
import 'signal_bubble_metrics.dart';

/// A video in a bubble, held to the same bounds as a photo — Signal sizes both
/// off `media_bubble_*`, so a mixed album does not step in and out.
class AttachmentVideoTile extends StatelessWidget {
  const AttachmentVideoTile({super.key, required this.attachment});

  final ChatMessageAttachment attachment;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: SignalBubbleMetrics.mediaMaxWidth,
        ),
        child: AttachmentGate(
          attachment: attachment,
          reserveSpace: true,
          height: SignalBubbleMetrics.mediaDefaultSize,
          width: SignalBubbleMetrics.mediaMaxWidth,
          ready: (_, handle) => NetworkVideoPlayer(
            source: VideoSource.file(handle.localPath!),
            fileName: attachment.fileName,
            maxHeight: SignalBubbleMetrics.mediaMaxHeight,
          ),
        ),
      ),
    );
  }
}
