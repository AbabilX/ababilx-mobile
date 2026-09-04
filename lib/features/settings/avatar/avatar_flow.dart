import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/media/image_crop_editor.dart';
import '../../../shared/media/pick_image_bytes.dart';
import '../../profile/providers/profile_provider.dart';

/// Signal's avatar flow: pick a photo, then move and scale it in a circular
/// window, then it is your avatar. Two screens, no form.
Future<void> startAvatarFlow(BuildContext context, WidgetRef ref) async {
  final bytes = await pickImageBytes(context);
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
