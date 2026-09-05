import 'package:flutter/material.dart';

import 'device_gallery.dart';
import 'media_folder_gallery.dart';

/// Wallpaper photo: Signal folder gallery on Android, not the Recent sheet.
///
/// Returns a local cache path suitable for [ChatWallpaper.photo], or null when
/// the user cancels / library is unreadable.
Future<String?> pickWallpaperPhoto(BuildContext context) async {
  // No camera button here: a wallpaper is picked, not taken.
  final result = await showMediaFolderGallery(context);
  final item = result?.item;
  if (item == null) return null;
  final file = await DeviceGallery.materialize(item);
  return file?.path;
}
