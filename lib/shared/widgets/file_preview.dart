import 'package:flutter/material.dart';

import 'file_preview_dialog.dart';
import 'file_preview_kind.dart';
import 'image_preview_chrome.dart';
import 'pdf_preview.dart';

/// One entry for every non-media file: PDF renders here, office/sheets
/// get the same chrome and an Open button.
Future<void> showFilePreview(
  BuildContext context, {
  required String fileName,
  String contentType = '',
  String? localPath,
  String? remoteUrl,
  String? detail,
  String? caption,
  int sizeBytes = 0,
}) {
  final kind = FilePreviewKind.of(fileName: fileName, contentType: contentType);
  if (kind == FilePreviewKind.pdf) {
    final path = localPath?.trim() ?? '';
    final url = remoteUrl?.trim() ?? '';
    final source = path.isNotEmpty
        ? PdfDocumentSource.file(path)
        : PdfDocumentSource.url(url);
    return showPdfPreview(
      context,
      source: source,
      fileName: fileName,
      detail: detail,
      caption: caption,
    );
  }
  return showDialog<void>(
    context: context,
    barrierColor: ImagePreviewChrome.background,
    builder: (_) => FilePreviewDialog(
      fileName: fileName,
      contentType: contentType,
      localPath: localPath,
      remoteUrl: remoteUrl,
      detail: detail,
      caption: caption,
      sizeBytes: sizeBytes,
    ),
  );
}
