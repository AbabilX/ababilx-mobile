import 'package:flutter/material.dart';

import '../../../shared/widgets/voice_url_player.dart';
import '../../attachments/widgets/attachment_gate.dart';
import '../data/models/chat_models.dart';

class VoiceAttachmentPlayer extends StatelessWidget {
  const VoiceAttachmentPlayer({super.key, required this.attachment});

  final ChatMessageAttachment attachment;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: AttachmentGate(
        attachment: attachment,
        reserveSpace: true,
        height: 58,
        width: 240,
        showSize: false,
        ready: (_, handle) => VoiceUrlPlayer(
          source: AudioSourceRef.file(handle.localPath!),
          fileName: attachment.fileName,
        ),
      ),
    );
  }
}
