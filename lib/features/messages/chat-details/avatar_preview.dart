import 'package:flutter/material.dart';

import '../../../shared/widgets/image_preview.dart';

/// Opens the shared fullscreen viewer for a group or member photo.
///
/// A letter-only avatar has no URL, so this is a no-op there — previewing
/// a '?' is not a picture. AppAvatar downsizes Google photos to 128px for
/// the circle; the viewer wants the larger crop.
void openAvatarPreview(
  BuildContext context, {
  required String? url,
  required String name,
}) {
  final src = previewPhotoUrl(url);
  if (src == null) return;
  final label = name.trim();
  showImagePreview(
    context,
    images: [
      PreviewImage(
        fileUrl: src,
        fileName: label.isEmpty ? 'photo.jpg' : '$label.jpg',
      ),
    ],
    initialIndex: 0,
  );
}

/// The URL the viewer should fetch, or null when there is no photo.
String? previewPhotoUrl(String? url) {
  final raw = url?.trim() ?? '';
  if (raw.isEmpty) return null;
  if (raw.contains('googleusercontent.com')) {
    return raw.replaceFirst(RegExp(r'=s\d+-c'), '=s720-c');
  }
  return raw;
}
