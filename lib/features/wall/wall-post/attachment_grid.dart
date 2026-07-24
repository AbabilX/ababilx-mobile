import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../data/models/wall_models.dart';
import 'file_preview.dart';
import 'image_preview.dart';

class WallAttachmentGrid extends StatelessWidget {
  const WallAttachmentGrid({super.key, required this.attachments});

  final List<WallAttachment> attachments;

  @override
  Widget build(BuildContext context) {
    final images = attachments.where((a) => a.isImage).toList();
    final pdfs = attachments.where((a) => !a.isImage && a.isPdf).toList();
    final others =
        attachments.where((a) => !a.isImage && !a.isPdf).toList();
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (images.isNotEmpty)
          SizedBox(
            height: 140,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final a = images[i];
                return GestureDetector(
                  onTap: () => showWallImagePreview(
                    context,
                    images: images,
                    initialIndex: i,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: a.fileUrl,
                      width: 160,
                      height: 140,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => Container(
                        width: 160,
                        color: scheme.surfaceContainerHighest,
                      ),
                      errorWidget: (_, _, _) => Container(
                        width: 160,
                        color: scheme.surfaceContainerHighest,
                        alignment: Alignment.center,
                        child: const Icon(Icons.broken_image_outlined),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        for (final pdf in pdfs)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.picture_as_pdf_outlined),
            title: Text(pdf.fileName, overflow: TextOverflow.ellipsis),
            subtitle: const Text('Tap to preview'),
            onTap: () => openWallPdfPreview(context, pdf),
          ),
        for (final f in others)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.attach_file),
            title: Text(f.fileName, overflow: TextOverflow.ellipsis),
            onTap: () => openWallFile(context, f),
          ),
      ],
    );
  }
}
