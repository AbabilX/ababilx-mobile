import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/media/image_crop_editor.dart';
import '../../../shared/media/pick_image_bytes.dart';
import '../../profile/providers/profile_provider.dart';
import '../../../shared/widgets/app_toast.dart';

/// Signal's avatar flow: pick a photo, then move and scale it in a circular
/// window, then it is your avatar. Two screens, no form.
Future<void> startAvatarFlow(BuildContext context, WidgetRef ref) async {
  final bytes = await pickImageBytes(context);
  if (bytes == null || !context.mounted) return;

  final cropped = await Navigator.of(context).push<Uint8List>(
    MaterialPageRoute(builder: (_) => ImageCropEditor(bytes: bytes)),
  );
  if (cropped == null || !context.mounted) return;

  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  try {
    await ref.read(profileProvider.notifier).updateAvatar(cropped);
    showAppToastIn(overlay, 'Profile photo updated');
  } catch (error) {
    showAppToastIn(overlay, 'Could not update photo: $error', isError: true);
  }
}
