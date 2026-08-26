import 'package:flutter/material.dart';

import 'video_fullscreen_dialog.dart';
import 'video_source.dart';

Future<void> showVideoPreview(
  BuildContext context, {
  required VideoSource source,
  String fileName = '',
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.96),
    builder: (_) => FullscreenVideoDialog(source: source, fileName: fileName),
  );
}
