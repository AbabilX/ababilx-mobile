import 'package:flutter/material.dart';

import 'device_gallery.dart';
import 'media_grid_body.dart';

/// What the user chose from the media sheet.
enum MediaSheetAction { picked, camera, files }

class MediaSheetResult {
  const MediaSheetResult(this.action, [this.items = const []]);

  final MediaSheetAction action;
  final List<DeviceMediaItem> items;
}

/// Signal's attachment keyboard: the library itself, in the sheet, rather than
/// a menu that launches the system picker.
///
/// Returns null when dismissed. When the device library is unreadable — no
/// permission, or a platform without the channel — this returns
/// [MediaSheetAction.files] immediately so the caller falls straight through
/// to the system picker instead of presenting an empty grid.
Future<MediaSheetResult?> showMediaGridSheet(
  BuildContext context, {
  bool allowMultiple = true,
  bool allowVideo = true,
  bool allowFiles = true,
  int maxSelection = 10,
  String title = 'Recent',
}) async {
  if (!await DeviceGallery.requestAccess()) {
    return const MediaSheetResult(MediaSheetAction.files);
  }
  if (!context.mounted) return null;

  return showModalBottomSheet<MediaSheetResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.62,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => MediaGridBody(
        scrollController: scrollController,
        allowMultiple: allowMultiple,
        allowVideo: allowVideo,
        allowFiles: allowFiles,
        maxSelection: maxSelection,
        title: title,
      ),
    ),
  );
}
