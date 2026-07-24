import 'package:flutter/material.dart';

import '../../../shared/widgets/image_preview.dart';
import '../data/models/wall_models.dart';

/// Wall wrapper — maps [WallAttachment] into shared fullscreen preview.
Future<void> showWallImagePreview(
  BuildContext context, {
  required List<WallAttachment> images,
  required int initialIndex,
}) {
  return showImagePreview(
    context,
    images: [
      for (final a in images)
        PreviewImage(fileUrl: a.fileUrl, fileName: a.fileName),
    ],
    initialIndex: initialIndex,
  );
}
