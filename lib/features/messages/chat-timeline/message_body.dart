import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../data/models/chat_models.dart';
import '../tiptap_plain_text.dart';

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
        ),
      );
    }
    final plain = tiptapToPlainText(message.body);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (message.forwardedFromName != null)
          Text(
            'Forwarded from ${message.forwardedFromName}',
            style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
          ),
        if (plain.isNotEmpty) MentionText(text: plain),
        ...message.attachments.map((a) => _Attachment(attachment: a)),
      ],
    );
  }
}

class MentionText extends StatelessWidget {
  const MentionText({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final spans = <InlineSpan>[];
    final re = RegExp(r'(@[\w.\- ]+)');
    var start = 0;
    for (final m in re.allMatches(text)) {
      if (m.start > start) {
        spans.add(TextSpan(text: text.substring(start, m.start)));
      }
      spans.add(TextSpan(
        text: m.group(0),
        style: TextStyle(color: colors.primary, fontWeight: FontWeight.w600),
      ));
      start = m.end;
    }
    if (start < text.length) spans.add(TextSpan(text: text.substring(start)));
    return Text.rich(
      TextSpan(
        style: TextStyle(color: colors.onSurface, height: 1.35),
        children: spans,
      ),
    );
  }
}

class _Attachment extends StatelessWidget {
  const _Attachment({required this.attachment});
  final ChatMessageAttachment attachment;

  @override
  Widget build(BuildContext context) {
    if (attachment.contentType.startsWith('image/')) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: attachment.fileUrl,
            height: 160,
            fit: BoxFit.cover,
          ),
        ),
      );
    }
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: HugeIcon(
        icon: HugeIcons.strokeRoundedFile01,
        size: 20,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      title: Text(
        attachment.fileName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
