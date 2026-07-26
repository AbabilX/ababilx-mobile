import 'package:flutter/material.dart';

import '../../../shared/widgets/voice_url_player.dart';
import '../data/models/chat_models.dart';

class VoiceAttachmentPlayer extends StatelessWidget {
  const VoiceAttachmentPlayer({super.key, required this.attachment});

  final ChatMessageAttachment attachment;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: VoiceUrlPlayer(
        url: attachment.fileUrl,
        fileName: attachment.fileName,
      ),
    );
  }
}
