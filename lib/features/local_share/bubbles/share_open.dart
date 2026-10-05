import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/image_preview.dart';
import '../engine/store/share_records.dart';

/// Opens a finished file: a photo in the app's own viewer (with the other
/// photos of its bubble beside it), anything else in whatever app handles it.
Future<void> openShareFile(
  BuildContext context,
  ShareFileRecord file,
  List<ShareFileRecord> siblings, {
  required String missingText,
}) async {
  if (!await File(file.localPath).exists()) {
    if (context.mounted) showAppToast(context, missingText, isError: true);
    return;
  }
  if (!context.mounted) return;
  if (file.mime.startsWith('image/')) {
    final images = [
      for (final f in siblings)
        if (f.mime.startsWith('image/') && File(f.localPath).existsSync()) f,
    ];
    final index = images.indexWhere((f) => f.id == file.id);
    return showImagePreview(
      context,
      images: [
        for (final f in images)
          PreviewImage(fileUrl: '', fileName: f.name, localPath: f.localPath),
      ],
      initialIndex: index < 0 ? 0 : index,
      allowRemoteFallback: false,
    );
  }
  await OpenFilex.open(file.localPath, type: file.mime);
}
