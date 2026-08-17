import 'package:flutter/material.dart';

import '../../../shared/widgets/link_preview.dart';
import '../data/models/chat_models.dart';
import '../tiptap_plain_text.dart';
import '../tiptap_viewer.dart';
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
          TiptapViewer(
            content: message.body,
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 15,
              height: 1.4,
            ),
            trailing: message.editedAt == null
                ? null
                : TextSpan(
                    text: ' (edited)',
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
          ),
        if (plain.isNotEmpty) MessageLinkPreviews(text: plain),
        if (message.attachments.isNotEmpty)
          MessageAttachments(attachments: message.attachments),
      ],
    );
  }
}
