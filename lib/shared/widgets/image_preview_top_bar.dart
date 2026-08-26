import 'package:flutter/material.dart';

import 'media_preview_actions.dart';
import 'preview_image.dart';

/// Signal's media toolbar: what you are looking at on the left, where you are
/// in the album on the right, and the overflow that holds Save.
class ImagePreviewTopBar extends StatelessWidget {
  const ImagePreviewTopBar({
    super.key,
    required this.image,
    required this.index,
    required this.total,
    required this.allowRemoteFallback,
  });

  final PreviewImage image;
  final int index;
  final int total;

  /// True for the wall and CRM viewers, which render straight from the URL —
  /// so saving may fetch it. Chat passes false and stays on its own pipeline.
  final bool allowRemoteFallback;

  static const _shadow = [Shadow(blurRadius: 8, color: Colors.black87)];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            image.fileName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              shadows: _shadow,
            ),
          ),
        ),
        if (total > 1) ...[
          const SizedBox(width: 8),
          Text(
            '${index + 1}/$total',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              shadows: _shadow,
            ),
          ),
        ],
        MediaPreviewOverflow(
          localPath: image.localPath,
          remoteUrl: allowRemoteFallback ? image.fileUrl : null,
          fileName: image.fileName,
        ),
      ],
    );
  }
}
