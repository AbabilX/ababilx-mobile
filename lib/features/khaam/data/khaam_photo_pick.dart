import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../shared/media/image_crop_editor.dart';
import '../../../shared/media/pick_image_bytes.dart';
import 'khaam_photo_compress.dart';

/// Pick a memory out of the whole library (albums first — it is rarely from
/// this week) and frame it as the envelope's portrait upper panel (3:4). Returns the cropped JPEG, or null
/// if the user backed out of either step. The crop is then squeezed under
/// [khaamPhotoMaxBytes].
Future<Uint8List?> pickKhaamPhoto(BuildContext context, String title) async {
  final bytes = await pickImageBytes(context, title: title);
  if (bytes == null || !context.mounted) return null;
  final cropped = await Navigator.of(context).push<Uint8List>(
    MaterialPageRoute(
      builder: (_) => ImageCropEditor(
        bytes: bytes,
        shape: CropShape.photo,
        // 960×1280: the envelope is never wider than ~300dp, so this covers
        // a 3x screen.
        outputWidth: 960,
        title: title,
      ),
    ),
  );
  return cropped == null ? null : compressKhaamPhoto(cropped);
}
