import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../data/models/wall_models.dart';
import 'file_preview.dart';
import 'image_preview.dart';

/// Web parity: solo min(360, 55vw); multi 96×170 thumbs; object-contain.
class WallAttachmentGrid extends StatelessWidget {
  const WallAttachmentGrid({super.key, required this.attachments});

  final List<WallAttachment> attachments;

  static const double _soloMaxH = 360;
  static const double _multiW = 96;
  static const double _multiH = 170;

  @override
  Widget build(BuildContext context) {
    final images = attachments.where((a) => a.isImage).toList();
    final pdfs = attachments.where((a) => !a.isImage && a.isPdf).toList();
    final others =
        attachments.where((a) => !a.isImage && !a.isPdf).toList();
    final scheme = Theme.of(context).colorScheme;
    final screenW = MediaQuery.sizeOf(context).width;
    final soloH = (_soloMaxH).clamp(0.0, screenW * 0.55);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (images.length == 1)
          GestureDetector(
            onTap: () => showWallImagePreview(
              context,
              images: images,
              initialIndex: 0,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: soloH,
                  minHeight: 120,
                ),
                child: CachedNetworkImage(
                  imageUrl: images.first.fileUrl,
                  width: double.infinity,
                  fit: BoxFit.contain,
                  alignment: Alignment.centerLeft,
                  placeholder: (_, _) => Container(
                    height: soloH * 0.6,
                    width: double.infinity,
                    color: scheme.surfaceContainerHighest,
                  ),
                  errorWidget: (_, _, _) => Container(
                    height: 140,
                    color: scheme.surfaceContainerHighest,
                    alignment: Alignment.center,
                    child: const Icon(Icons.broken_image_outlined),
                  ),
                ),
              ),
            ),
          )
        else if (images.isNotEmpty)
          SizedBox(
            height: _multiH,
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
                    child: ColoredBox(
                      color: scheme.surfaceContainerHighest,
                      child: CachedNetworkImage(
                        imageUrl: a.fileUrl,
                        width: _multiW,
                        height: _multiH,
                        fit: BoxFit.contain,
                        alignment: Alignment.topLeft,
                        placeholder: (_, _) => SizedBox(
                          width: _multiW,
                          height: _multiH,
                        ),
                        errorWidget: (_, _, _) => SizedBox(
                          width: _multiW,
                          height: _multiH,
                          child: const Center(
                            child: Icon(Icons.broken_image_outlined),
                          ),
                        ),
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
