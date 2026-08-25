import 'package:flutter/material.dart';

import 'pdf_document_source.dart';
import 'pdf_fullscreen_dialog.dart';
import 'pdf_preview_thumb.dart';

export 'pdf_document_source.dart';

Future<void> showPdfPreview(
  BuildContext context, {
  required PdfDocumentSource source,
  required String fileName,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.92),
    builder: (_) => PdfFullscreenDialog(source: source, fileName: fileName),
  );
}

class PdfPreviewCard extends StatelessWidget {
  const PdfPreviewCard({
    super.key,
    required this.source,
    required this.fileName,
    this.hideFileName = false,
    this.height = 260,
  });

  final PdfDocumentSource source;
  final String fileName;
  final bool hideFileName;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      borderRadius: hideFileName ? null : BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () =>
            showPdfPreview(context, source: source, fileName: fileName),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!hideFileName) _header(context),
            PdfPreviewThumb(source: source, height: height),
          ],
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
          Icon(Icons.picture_as_pdf_rounded, color: colors.error),
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
