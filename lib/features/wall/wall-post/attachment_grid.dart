import 'package:flutter/material.dart';

import '../../../shared/widgets/locked_file_placeholder.dart';
import '../../../shared/widgets/pdf_preview.dart';
import '../data/models/wall_models.dart';
import 'feed_images.dart';
import 'file_preview.dart';

/// Web parity ([wall-attachment-grid.tsx]):
/// - images → [WallFeedImages] (solo / wide-pair / packed)
/// - PDFs → first-page thumb, hide filename
/// - video / audio / docs / zip → bordered filename chips (no inline players)
/// - locked → lock chip
class WallAttachmentGrid extends StatelessWidget {
  const WallAttachmentGrid({super.key, required this.attachments});

  final List<WallAttachment> attachments;

  @override
  Widget build(BuildContext context) {
    final lockedFiles = attachments.where((a) => a.locked).toList();
    final open = attachments.where((a) => !a.locked).toList();
    final images = open.where((a) => a.isImage).toList();
    final pdfs = open.where((a) => !a.isImage && a.isPdf).toList();
    // Match web: everything that is not image/PDF is a chip — including video/audio.
    final otherFiles = open.where((a) => !a.isImage && !a.isPdf).toList();
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (images.isNotEmpty) WallFeedImages(images: images),
        if (pdfs.isNotEmpty)
          DecoratedBox(
            decoration: images.isNotEmpty
                ? BoxDecoration(
                    border: Border(
                      top: BorderSide(color: scheme.outlineVariant),
                    ),
                  )
                : const BoxDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final pdf in pdfs)
                  PdfPreviewCard(
                    source: PdfDocumentSource.url(pdf.fileUrl),
                    fileName: pdf.fileName,
                    hideFileName: true,
                    height: 360,
                  ),
              ],
            ),
          ),
        if (otherFiles.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(
              top: images.isEmpty && pdfs.isEmpty ? 0 : 8,
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final f in otherFiles)
                  _OtherFileChip(
                    attachment: f,
                    onTap: () => openWallFile(context, f),
                  ),
              ],
            ),
          ),
        if (lockedFiles.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final f in lockedFiles)
                  LockedFilePlaceholder(fileName: f.fileName),
              ],
            ),
          ),
      ],
    );
  }
}

IconData _otherFileIcon(WallAttachment f) {
  final ct = f.contentType.toLowerCase();
  final name = f.fileName.toLowerCase();
  if (f.isVideo || ct.startsWith('video/')) {
    return Icons.videocam_outlined;
  }
  if (f.isAudio || ct.startsWith('audio/')) {
    return Icons.audiotrack_outlined;
  }
  if (ct.contains('zip') ||
      ct.contains('tar') ||
      ct.contains('gzip') ||
      ct.contains('compress') ||
      RegExp(r'\.(zip|rar|7z|tar|gz)$').hasMatch(name)) {
    return Icons.folder_zip_outlined;
  }
  if (ct.contains('presentation') || RegExp(r'\.pptx?$').hasMatch(name)) {
    return Icons.slideshow_outlined;
  }
  if (ct.contains('spreadsheet') ||
      ct.contains('excel') ||
      RegExp(r'\.(xlsx?|csv)$').hasMatch(name)) {
    return Icons.grid_on_outlined;
  }
  if (ct.contains('word') || RegExp(r'\.docx?$').hasMatch(name)) {
    return Icons.description_outlined;
  }
  return Icons.insert_drive_file_outlined;
}

/// Web parity: bordered chip with type icon + truncated name.
class _OtherFileChip extends StatelessWidget {
  const _OtherFileChip({required this.attachment, required this.onTap});

  final WallAttachment attachment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: scheme.outlineVariant),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_otherFileIcon(attachment), size: 16, color: scheme.primary),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: Text(
                  attachment.fileName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
