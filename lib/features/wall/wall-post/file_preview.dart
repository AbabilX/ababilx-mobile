import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/models/wall_models.dart';

Future<void> openWallPdfPreview(
  BuildContext context,
  WallAttachment pdf,
) async {
  final uri = Uri.tryParse(pdf.fileUrl);
  if (uri == null) {
    _toast(context, 'Invalid PDF URL');
    return;
  }

  final ok = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
  if (!ok && context.mounted) {
    final fallback = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!fallback && context.mounted) {
      _toast(context, 'Could not open PDF');
    }
  }
}

Future<void> openWallFile(
  BuildContext context,
  WallAttachment file,
) async {
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
