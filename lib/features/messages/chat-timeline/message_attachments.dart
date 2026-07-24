import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../shared/widgets/image_preview.dart';
import '../chat_icon.dart';
import '../data/models/chat_models.dart';
import 'chat_file_preview.dart';

/// Renders chat image + file attachments; tap opens preview / external file.
class MessageAttachments extends StatelessWidget {
  const MessageAttachments({super.key, required this.attachments});

  final List<ChatMessageAttachment> attachments;

  @override
  Widget build(BuildContext context) {
    final images = attachments.where((a) => a.isImage).toList();
    final files = attachments.where((a) => !a.isImage).toList();
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < images.length; i++)
          _ImageAttachment(
            attachment: images[i],
            placeholderColor: colors.surfaceContainerHighest,
            onTap: () => showImagePreview(
              context,
              images: [
                for (final a in images)
                  PreviewImage(fileUrl: a.fileUrl, fileName: a.fileName),
              ],
              initialIndex: i,
            ),
          ),
        for (final a in files)
          _FileAttachment(
            attachment: a,
            onTap: () => openChatAttachment(context, a),
          ),
      ],
    );
  }
}

class _ImageAttachment extends StatelessWidget {
  const _ImageAttachment({
    required this.attachment,
    required this.onTap,
    required this.placeholderColor,
  });

  final ChatMessageAttachment attachment;
  final VoidCallback onTap;
  final Color placeholderColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: attachment.fileUrl,
              width: double.infinity,
              height: 180,
              fit: BoxFit.cover,
              placeholder: (_, _) => Container(
                height: 180,
                color: placeholderColor,
              ),
              errorWidget: (_, _, _) => Container(
                height: 180,
                color: placeholderColor,
                alignment: Alignment.center,
                child: const Icon(Icons.broken_image_outlined),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FileAttachment extends StatelessWidget {
  const _FileAttachment({
    required this.attachment,
    required this.onTap,
  });

  final ChatMessageAttachment attachment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              ChatIcon(
                attachment.isPdf
                    ? HugeIcons.strokeRoundedPdf02
                    : HugeIcons.strokeRoundedFile01,
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
              Icon(
                Icons.open_in_new_rounded,
                size: 16,
                color: colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
