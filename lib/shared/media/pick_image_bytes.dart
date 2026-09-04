import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'device_gallery.dart';
import 'media_grid_sheet.dart';
import 'picked_media_file.dart';

/// Raw bytes of a picture the user chose, whichever route they took.
///
/// The library grid comes first because that is where the picture almost
/// always already is; Camera and the system picker are one tap away inside the
/// same sheet, and a device that will not give us the library falls through to
/// the system picker rather than a dead end.
Future<Uint8List?> pickImageBytes(
  BuildContext context, {
  String title = 'Choose a photo',
}) async {
  final result = await showMediaGridSheet(
    context,
    allowMultiple: false,
    allowVideo: false,
    allowFiles: false,
    title: title,
  );
  if (result == null) return null;

  switch (result.action) {
    case MediaSheetAction.picked:
      final item = result.items.firstOrNull;
      if (item == null) return null;
      final file = await DeviceGallery.materialize(item);
      return file?.readAsBytes();
    case MediaSheetAction.camera:
      final shot = await pickLiveCameraFile();
      return shot?.bytes;
    case MediaSheetAction.files:
      // Reached when the library is unreadable — the system picker still
      // works without any of the permissions we were denied.
      final picked = await pickGalleryImageFile();
      return picked?.bytes;
  }
}
