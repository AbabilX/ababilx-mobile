import 'package:flutter/material.dart';

import 'image_preview_chrome.dart';
import 'video_fullscreen_dialog.dart';
import 'video_source.dart';

Future<void> showVideoPreview(
  BuildContext context, {
  required VideoSource source,
  String fileName = '',
  String? detail,
  String? caption,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: ImagePreviewChrome.background,
    builder: (_) => FullscreenVideoDialog(
      source: source,
      fileName: fileName,
      detail: detail,
      caption: caption,
    ),
  );
}
