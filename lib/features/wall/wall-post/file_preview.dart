import 'package:flutter/material.dart';

import '../../../shared/widgets/file_preview.dart';
import '../../../shared/widgets/pdf_preview.dart';
import '../data/models/wall_models.dart';

Future<void> openWallPdfPreview(BuildContext context, WallAttachment pdf) =>
    showPdfPreview(
      context,
      source: PdfDocumentSource.url(pdf.fileUrl),
      fileName: pdf.fileName,
    );

Future<void> openWallFile(BuildContext context, WallAttachment file) async {
  if (file.locked || file.fileUrl.isEmpty) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('This file is locked')));
    return;
  }
  await showFilePreview(
    context,
    fileName: file.fileName,
    contentType: file.contentType,
    remoteUrl: file.fileUrl,
    sizeBytes: file.sizeBytes,
  );
}
