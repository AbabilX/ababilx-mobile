import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'device_gallery.dart';
import 'media_grid_sheet.dart';
import 'picked_media_file.dart';

/// One attachment, chosen through the in-app grid with Camera and Files as
/// escapes inside the same sheet.
///
/// Returns the bytes and, when the source was a real file on disk, its path —
/// so a caller that wants to draw a local preview does not have to fetch back
/// what it just uploaded.
class SingleMediaPick {
  const SingleMediaPick({required this.file, this.localPath});

  final PickedMediaFile file;
  final String? localPath;
}

Future<SingleMediaPick?> pickSingleMedia(
  BuildContext context, {
  bool allowVideo = true,
  bool allowFiles = true,
}) async {
  final result = await showMediaGridSheet(
    context,
    allowMultiple: false,
    allowVideo: allowVideo,
    allowFiles: allowFiles,
  );
  if (result == null) return null;

  switch (result.action) {
    case MediaSheetAction.camera:
      final shot = await pickLiveCameraFile();
      return shot == null ? null : SingleMediaPick(file: shot);
    case MediaSheetAction.files:
      final picked = allowFiles
          ? await pickDeviceFile()
          : await pickGalleryImageFile();
      return picked == null ? null : SingleMediaPick(file: picked);
    case MediaSheetAction.picked:
      final item = result.items.firstOrNull;
      if (item == null) return null;
      final file = await DeviceGallery.materialize(item);
      if (file == null) return null;
      return SingleMediaPick(
        file: PickedMediaFile(
          bytes: await file.readAsBytes(),
          fileName: item.name,
          contentType: item.mime,
        ),
        localPath: file.path,
      );
  }
}

/// Keeps a copy of picked bytes on disk so a preview tile can draw from the
/// file system instead of re-downloading the object that was just uploaded.
Future<String?> writePreviewCopy(String fileName, Uint8List bytes) async {
  try {
    final dir = Directory('${(await getTemporaryDirectory()).path}/previews');
    await dir.create(recursive: true);
    final safe = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final file = File(
      '${dir.path}/${DateTime.now().microsecondsSinceEpoch}-$safe',
    );
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  } catch (_) {
    return null;
  }
}
