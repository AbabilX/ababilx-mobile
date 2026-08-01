import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/widgets/pdf_preview.dart';
import '../data/models/wall_models.dart';

Future<void> openWallPdfPreview(
  BuildContext context,
  WallAttachment pdf,
) {
  return showPdfPreview(
    context,
    fileUrl: pdf.fileUrl,
    fileName: pdf.fileName,
  );
}

Future<void> openWallFile(
  BuildContext context,
  WallAttachment file,
) async {
  if (file.locked || file.fileUrl.isEmpty) {
    _toast(context, 'This file is locked');
    return;
  }
  final uri = Uri.tryParse(file.fileUrl);
  if (uri == null) {
    _toast(context, 'Invalid file URL');
    return;
  }
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) _toast(context, 'Could not open file');
}

void _toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}
