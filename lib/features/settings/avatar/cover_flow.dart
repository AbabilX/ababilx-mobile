import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/media/image_crop_editor.dart';
import '../../../shared/media/pick_image_bytes.dart';
import '../../profile/providers/profile_provider.dart';
import '../../../shared/widgets/app_toast.dart';

/// Same two screens as [startAvatarFlow], framed for a header strip.
///
/// Web uploads the file as-is; here we crop to the 3:1 window the details
/// header actually draws, so what you frame is what other people see.
Future<void> startCoverFlow(BuildContext context, WidgetRef ref) async {
  final bytes = await pickImageBytes(context, title: 'Choose a cover photo');
  if (bytes == null || !context.mounted) return;

  final cropped = await Navigator.of(context).push<Uint8List>(
    MaterialPageRoute(
      builder: (_) => ImageCropEditor(
        bytes: bytes,
        shape: CropShape.wide,
        outputWidth: 1280,
      ),
    ),
  );
  if (cropped == null || !context.mounted) return;

  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  try {
    await ref.read(profileProvider.notifier).updateCover(cropped);
    showAppToastIn(overlay, 'Cover photo updated');
  } catch (error) {
    showAppToastIn(overlay, 'Could not update cover: $error', isError: true);
  }
}
