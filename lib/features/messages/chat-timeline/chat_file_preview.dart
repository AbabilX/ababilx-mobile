import 'package:flutter/material.dart';

import '../../../shared/widgets/file_preview.dart';
import '../data/models/chat_models.dart';
import 'media-preview/chat_media_preview_meta.dart';

/// Chat files open the same viewer as photos — PDF renders, office/sheets
/// show the chrome + Open. We never jump straight to another app.
Future<void> openChatAttachment(
  BuildContext context,
  ChatMessageAttachment file, {
  required String localPath,
  ChatMediaPreviewMeta? preview,
}) async {
  if (file.locked || localPath.isEmpty) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('This file is not available')));
    return;
  }
  await showFilePreview(
    context,
    fileName: file.fileName,
    contentType: file.contentType,
    localPath: localPath,
    detail: preview?.detail,
    caption: preview?.caption,
    sizeBytes: file.sizeBytes,
  );
}
