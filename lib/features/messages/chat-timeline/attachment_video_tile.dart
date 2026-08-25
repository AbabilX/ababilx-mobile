import 'package:flutter/material.dart';

import '../../../shared/widgets/network_video_player.dart';
import '../../attachments/widgets/attachment_gate.dart';
import '../data/models/chat_models.dart';

class AttachmentVideoTile extends StatelessWidget {
  const AttachmentVideoTile({super.key, required this.attachment});

  final ChatMessageAttachment attachment;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: AttachmentGate(
        attachment: attachment,
        height: 160,
        ready: (_, handle) => NetworkVideoPlayer(
          source: VideoSource.file(handle.localPath!),
          maxHeight: 288,
        ),
      ),
    );
  }
}
