import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/models/chat_models.dart';

Future<void> openChatAttachment(
  BuildContext context,
  ChatMessageAttachment file,
) async {
  final uri = Uri.tryParse(file.fileUrl);
  if (uri == null) {
    _toast(context, 'Invalid file URL');
    return;
  }

  if (file.isPdf) {
    final ok = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    if (!ok && context.mounted) {
      final fallback =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!fallback && context.mounted) _toast(context, 'Could not open PDF');
    }
    return;
  }

  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) _toast(context, 'Could not open file');
}

void _toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}
