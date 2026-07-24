import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../shared/widgets/image_preview.dart';
import '../chat_icon.dart';
import '../data/models/chat_models.dart';

/// Renders chat image + file attachments; images open shared fullscreen preview.
class MessageAttachments extends StatelessWidget {
  const MessageAttachments({super.key, required this.attachments});

  final List<ChatMessageAttachment> attachments;

  @override
  Widget build(BuildContext context) {
    final images =
        attachments.where((a) => a.contentType.startsWith('image/')).toList();
    final files =
        attachments.where((a) => !a.contentType.startsWith('image/')).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < images.length; i++)
          _ImageAttachment(
            attachment: images[i],
            onTap: () => showImagePreview(
              context,
              images: [
                for (final a in images)
                  PreviewImage(fileUrl: a.fileUrl, fileName: a.fileName),
              ],
              initialIndex: i,
            ),
          ),
        for (final a in files) _FileAttachment(attachment: a),
      ],
    );
  }
}

class _ImageAttachment extends StatelessWidget {
  const _ImageAttachment({
    required this.attachment,
    required this.onTap,
  });

  final ChatMessageAttachment attachment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: attachment.fileUrl,
            height: 180,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}

class _FileAttachment extends StatelessWidget {
  const _FileAttachment({required this.attachment});
  final ChatMessageAttachment attachment;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
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
