import 'package:flutter/material.dart';

import '../data/models/chat_models.dart';
import 'attachment_album_geometry.dart';
import 'attachment_image_tile.dart';
import 'media-preview/chat_media_preview_meta.dart';
import 'signal_bubble_metrics.dart';

/// Signal's album: one image drawn full width, several laid out by
/// [albumLayout] with `+N` over the last cell when there are more than five.
///
/// Every image in the message stays in [gallery] whatever the cell count, so
/// the sixth photo of an album of eight is one swipe away in the viewer and
/// can be downloaded there.
class AttachmentImageGrid extends StatelessWidget {
  const AttachmentImageGrid({
    super.key,
    required this.images,
    this.withCaption = false,
    this.preview,
  });

  final List<ChatMessageAttachment> images;

  /// A picture carrying text is held to a wider floor, so the caption is not
  /// squeezed into a narrow bubble beneath it.
  final bool withCaption;

  final ChatMediaPreviewMeta? preview;

  static const double _corner = 14;
  static const double _maxWidth = SignalBubbleMetrics.mediaMaxWidth;

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) return const SizedBox.shrink();
    if (images.length == 1) {
      return AttachmentImageTile(
        attachment: images.first,
        gallery: images,
        index: 0,
        maxHeight: SignalBubbleMetrics.mediaMaxHeight,
        maxWidth: SignalBubbleMetrics.mediaMaxWidth,
        minWidth: withCaption
            ? SignalBubbleMetrics.mediaMinWidthWithCaption
            : SignalBubbleMetrics.mediaMinWidthSolo,
        preview: preview,
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final available = constraints.hasBoundedWidth
              ? constraints.maxWidth
              : _maxWidth;
          final width = available < _maxWidth ? available : _maxWidth;
          final layout = albumLayout(
            count: images.length,
            width: width,
            corner: _corner,
          );
          return SizedBox(
            width: width,
            height: layout.height,
            child: Stack(
              children: [
                for (final cell in layout.cells)
                  Positioned.fromRect(
                    rect: cell.rect,
                    child: AttachmentImageTile(
                      attachment: images[cell.index],
                      gallery: images,
                      index: cell.index,
                      maxHeight: cell.rect.height,
                      maxWidth: cell.rect.width,
                      grid: true,
                      radius: cell.radius,
                      preview: preview,
                      overlayText:
                          layout.overflow > 0 &&
                              cell.index == layout.cells.last.index
                          ? '+${layout.overflow}'
                          : null,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
