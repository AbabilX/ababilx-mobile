import 'package:flutter/material.dart';

import 'image_preview_chrome.dart';
import 'pdf_document_source.dart';
import 'pdf_fullscreen_dialog.dart';
import 'pdf_preview_thumb.dart';
import 'preview_icon.dart';

export 'pdf_document_source.dart';

Future<void> showPdfPreview(
  BuildContext context, {
  required PdfDocumentSource source,
  required String fileName,
  String? detail,
  String? caption,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: ImagePreviewChrome.background,
    builder: (_) => PdfFullscreenDialog(
      source: source,
      fileName: fileName,
      detail: detail,
      caption: caption,
    ),
  );
}

class PdfPreviewCard extends StatelessWidget {
  const PdfPreviewCard({
    super.key,
    required this.source,
    required this.fileName,
    this.hideFileName = false,
    this.height = 260,
    this.flat = false,
    this.detail,
    this.caption,
  });

  final PdfDocumentSource source;
  final String fileName;
  final bool hideFileName;
  final double height;

  /// Square corners, for a card that fills a clipped bubble.
  final bool flat;
  final String? detail;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      borderRadius: hideFileName || flat ? null : BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showPdfPreview(
          context,
          source: source,
          fileName: fileName,
          detail: detail,
          caption: caption,
        ),
        child: SizedBox(
          height: height,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!hideFileName) _header(context),
              Expanded(child: PdfPreviewThumb(source: source)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.outlineVariant)),
        color: colors.surfaceContainerHighest.withValues(alpha: 0.35),
      ),
      child: Row(
        children: [
          PreviewIcon(PreviewIcons.pdf, color: colors.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
        ],
      ),
    );
  }
}
