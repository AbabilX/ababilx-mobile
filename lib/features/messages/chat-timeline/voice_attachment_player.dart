import 'package:flutter/material.dart';

import '../../../shared/widgets/voice_flat_layout.dart';
import '../../../shared/widgets/voice_url_player.dart';
import '../../attachments/widgets/attachment_gate.dart';
import '../data/models/chat_models.dart';
import 'voice_attachment_waiting.dart';
import 'voice_bubble_footer.dart';

class VoiceAttachmentPlayer extends StatelessWidget {
  const VoiceAttachmentPlayer({super.key, required this.attachment});

  final ChatMessageAttachment attachment;

  @override
  Widget build(BuildContext context) {
    final footer = VoiceBubbleFooter.of(context);
    // The bubble's own inset is the only padding: a second pill with its own
    // fill and padding inside it read as a box in a box.
    return AttachmentGate(
      attachment: attachment,
      reserveSpace: true,
      height: VoiceRowFrame.height,
      width: VoiceRowFrame.width,
      showSize: false,
      waiting: (_, handle) => VoiceAttachmentWaiting(
        attachment: attachment,
        handle: handle,
        trailing: footer,
      ),
      ready: (_, handle) => VoiceUrlPlayer(
        source: AudioSourceRef.file(handle.localPath!),
        fileName: attachment.fileName,
        flat: true,
        trailing: footer,
        waveSeed: attachment.fileUrl,
      ),
    );
  }
}
