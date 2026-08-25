import 'package:flutter/material.dart';

import '../data/models/chat_models.dart';
import 'attachment_image_tile.dart';

class AttachmentImageGrid extends StatelessWidget {
  const AttachmentImageGrid({super.key, required this.images});

  final List<ChatMessageAttachment> images;

  static const _gap = 3.0;
  static const _maxVisible = 4;

  @override
  Widget build(BuildContext context) {
    if (images.length == 1) {
      return AttachmentImageTile(
        attachment: images.first,
        gallery: images,
        index: 0,
        maxHeight: 288,
        maxWidth: double.infinity,
      );
    }
    final visibleCount = images.length.clamp(0, _maxVisible);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.hasBoundedWidth
              ? constraints.maxWidth
              : 280.0;
          final tileWidth = (width - _gap) / 2;
          return Wrap(
            spacing: _gap,
            runSpacing: _gap,
            children: [
              for (var index = 0; index < visibleCount; index++)
                SizedBox(
                  width: tileWidth,
                  height: tileWidth,
                  child: AttachmentImageTile(
                    attachment: images[index],
                    gallery: images,
                    index: index,
                    maxHeight: tileWidth,
                    maxWidth: tileWidth,
                    grid: true,
                    overlayText:
                        index == _maxVisible - 1 && images.length > _maxVisible
                        ? '+${images.length - _maxVisible}'
                        : null,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
