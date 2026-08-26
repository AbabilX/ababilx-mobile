import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/media/device_gallery.dart';
import '../../../shared/media/image_crop_editor.dart';
import '../../../shared/media/media_grid_sheet.dart';
import '../../../shared/media/picked_media_file.dart';
import '../../profile/providers/profile_provider.dart';

/// Signal's avatar flow: pick a photo, then move and scale it in a circular
/// window, then it is your avatar. Two screens, no form.
///
/// The library grid comes first because that is where the picture almost
/// always already is; Camera and the system picker are one tap away inside the
/// same sheet, and a device that will not give us the library falls through to
/// the system picker rather than a dead end.
Future<void> startAvatarFlow(BuildContext context, WidgetRef ref) async {
  final bytes = await _sourceBytes(context);
  if (bytes == null || !context.mounted) return;

  final cropped = await Navigator.of(context).push<Uint8List>(
    MaterialPageRoute(builder: (_) => ImageCropEditor(bytes: bytes)),
  );
  if (cropped == null || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref.read(profileProvider.notifier).updateAvatar(cropped);
    messenger.showSnackBar(
      const SnackBar(content: Text('Profile photo updated')),
    );
  } catch (error) {
    messenger.showSnackBar(
      SnackBar(content: Text('Could not update photo: $error')),
    );
  }
}

/// Raw bytes of whatever the user chose, whichever route they took.
Future<Uint8List?> _sourceBytes(BuildContext context) async {
  final result = await showMediaGridSheet(
    context,
    allowMultiple: false,
    allowVideo: false,
    allowFiles: false,
    title: 'Choose a photo',
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
