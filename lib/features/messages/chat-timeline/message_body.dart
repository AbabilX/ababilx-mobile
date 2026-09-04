import 'package:flutter/material.dart';

import '../../../shared/widgets/link_preview.dart';
import '../data/models/chat_models.dart';
import '../tiptap_plain_text.dart';
import '../tiptap_viewer.dart';
import 'message_attachments.dart';
import 'message_bubble.dart';
import 'signal_bubble_metrics.dart';

class MessageBody extends StatelessWidget {
  const MessageBody({super.key, required this.message, required this.colors});

  final ChatMessage message;

  /// Text sits on the bubble's fill, so every colour here comes from the
  /// bubble rather than straight off the scheme.
  final SignalBubbleColors colors;

  @override
  Widget build(BuildContext context) {
    if (message.isDeleted) {
      return Text(
        'This message was deleted',
        style: TextStyle(
          color: colors.muted,
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
              style: TextStyle(fontSize: 12, color: colors.muted),
            ),
          ),
        if (plain.isNotEmpty)
          TiptapViewer(
            content: message.body,
            style: TextStyle(
              color: colors.foreground,
              fontSize: SignalBubbleMetrics.bodyTextSize,
              height: 1.35,
            ),
            trailing: message.editedAt == null
                ? null
                : TextSpan(
                    text: ' (edited)',
                    style: TextStyle(fontSize: 12, color: colors.muted),
                  ),
          ),
        if (plain.isNotEmpty) MessageLinkPreviews(text: plain),
        if (message.attachments.isNotEmpty)
          MessageAttachments(
            attachments: message.attachments,
            withCaption: plain.isNotEmpty,
          ),
      ],
    );
  }
}
