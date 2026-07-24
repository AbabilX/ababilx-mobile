import 'package:flutter/material.dart';

import '../data/models/chat_models.dart';
import '../tiptap_plain_text.dart';
import 'mention_text.dart';
import 'message_attachments.dart';

class MessageBody extends StatelessWidget {
  const MessageBody({super.key, required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (message.isDeleted) {
      return Text(
        'This message was deleted',
        style: TextStyle(
          color: colors.onSurfaceVariant,
          fontStyle: FontStyle.italic,
          fontSize: 15,
        ),
      );
    }
    final plain = tiptapToPlainText(message.body);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (message.forwardedFromName != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              'Forwarded from ${message.forwardedFromName}',
              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
            ),
          ),
        if (plain.isNotEmpty)
          MentionText(text: plain, edited: message.editedAt != null),
        if (message.attachments.isNotEmpty)
          MessageAttachments(attachments: message.attachments),
      ],
    );
  }
}
