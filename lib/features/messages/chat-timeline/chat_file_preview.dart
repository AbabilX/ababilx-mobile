import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/widgets/pdf_preview.dart';
import '../data/models/chat_models.dart';

Future<void> openChatAttachment(
  BuildContext context,
  ChatMessageAttachment file,
) async {
  if (file.locked || file.fileUrl.isEmpty) {
    _toast(context, 'This file is locked');
    return;
  }
  if (file.isPdf) {
    await showPdfPreview(
      context,
      fileUrl: file.fileUrl,
      fileName: file.fileName,
    );
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
