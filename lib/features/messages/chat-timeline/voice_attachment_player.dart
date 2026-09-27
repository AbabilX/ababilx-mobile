import 'package:flutter/material.dart';

import '../../../shared/widgets/voice_url_player.dart';
import '../../attachments/widgets/attachment_gate.dart';
import '../data/models/chat_models.dart';

class VoiceAttachmentPlayer extends StatelessWidget {
  const VoiceAttachmentPlayer({super.key, required this.attachment});

  final ChatMessageAttachment attachment;

  @override
  Widget build(BuildContext context) {
    // The bubble's own inset is the only padding: a second pill with its own
    // fill and padding inside it read as a box in a box.
    return AttachmentGate(
      attachment: attachment,
      reserveSpace: true,
      height: 40,
      width: 220,
      showSize: false,
      ready: (_, handle) => VoiceUrlPlayer(
        source: AudioSourceRef.file(handle.localPath!),
        fileName: attachment.fileName,
        flat: true,
      ),
    );
  }
}
