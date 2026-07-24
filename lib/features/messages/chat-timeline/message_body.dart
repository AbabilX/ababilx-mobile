import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../chat_icon.dart';
import '../data/models/chat_models.dart';
import '../tiptap_plain_text.dart';
import 'mention_text.dart';

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
        ...message.attachments.map((a) => _Attachment(attachment: a)),
      ],
    );
  }
}

class _Attachment extends StatelessWidget {
  const _Attachment({required this.attachment});
  final ChatMessageAttachment attachment;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (attachment.contentType.startsWith('image/')) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: attachment.fileUrl,
            height: 180,
            fit: BoxFit.cover,
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          ChatIcon(
            HugeIcons.strokeRoundedFile01,
            size: 18,
            color: colors.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              attachment.fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colors.primary, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
