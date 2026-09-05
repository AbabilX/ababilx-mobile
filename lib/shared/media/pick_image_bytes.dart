import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'device_gallery.dart';
import 'media_folder_gallery.dart';
import 'picked_media_file.dart';

/// Raw bytes of a picture the user chose, whichever route they took.
///
/// Opens the album gallery, not the composer's Recent strip. A profile picture
/// or a group photo is a deliberate choice out of the whole library — usually
/// not something shot in the last hour — and Recent shows one screenful with no
/// way to reach an album from it.
///
/// Camera sits in the gallery's app bar, and a device that will not give us the
/// library falls through to the system picker rather than an empty screen.
Future<Uint8List?> pickImageBytes(
  BuildContext context, {
  String title = 'Choose a photo',
}) async {
  // Checked here as well as inside the gallery so the two failures stay
  // distinguishable: the gallery returns null both for "user backed out" and
  // for "no library", and only the second should reach the system picker.
  if (!await DeviceGallery.requestAccess()) {
    final picked = await pickGalleryImageFile();
    return picked?.bytes;
  }
  if (!context.mounted) return null;

  final result = await showMediaFolderGallery(
    context,
    title: title,
    allowCamera: true,
  );
  if (result == null) return null;

  switch (result.action) {
    case MediaGalleryAction.camera:
      final shot = await pickLiveCameraFile();
      return shot?.bytes;
    case MediaGalleryAction.picked:
      final item = result.item;
      if (item == null) return null;
      final file = await DeviceGallery.materialize(item);
      return file?.readAsBytes();
  }
}
