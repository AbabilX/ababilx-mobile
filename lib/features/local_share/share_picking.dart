import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../shared/media/device_gallery.dart';
import '../../shared/media/media_grid_sheet.dart';
import '../../shared/media/picked_media_file.dart' show contentTypeForFileName;
import 'local_share_actions.dart';

/// Photos and videos from the app's own gallery sheet. Every path returned is
/// a copy in the app's cache (a `content://` grant does not outlive the
/// picker), so each pick is [SharePick.owned] and moves into the thread.
Future<List<SharePick>> pickShareMedia(BuildContext context) async {
  final result = await showMediaGridSheet(context, maxSelection: 30);
  if (result == null) return const [];
  switch (result.action) {
    case MediaSheetAction.picked:
      final picks = <SharePick>[];
      for (final item in result.items) {
        final file = await DeviceGallery.materialize(item);
        if (file == null) continue;
        picks.add(
          SharePick(
            path: file.path,
            name: item.name,
            mime: item.mime,
            owned: true,
            width: item.width > 0 ? item.width : null,
            height: item.height > 0 ? item.height : null,
            durationMs: item.durationMs > 0 ? item.durationMs : null,
          ),
        );
      }
      return picks;
    case MediaSheetAction.camera:
      final shot = await ImagePicker().pickImage(source: ImageSource.camera);
      if (shot == null) return const [];
      return [
        SharePick(
          path: shot.path,
          name: shot.name,
          mime: shot.mimeType ?? contentTypeForFileName(shot.name),
          owned: true,
        ),
      ];
    case MediaSheetAction.files:
      return pickShareFiles();
  }
}

/// Any files, through the system picker. It hands over cache copies too.
Future<List<SharePick>> pickShareFiles() async {
  final result = await FilePicker.platform.pickFiles(allowMultiple: true);
  if (result == null) return const [];
  return [
    for (final file in result.files)
      if (file.path != null && File(file.path!).existsSync())
        SharePick(
          path: file.path!,
          name: file.name,
          mime: contentTypeForFileName(file.name),
          owned: true,
        ),
  ];
}
