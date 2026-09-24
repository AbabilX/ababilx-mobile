import 'package:flutter/material.dart';

import '../data/models/chat_models.dart';
import 'attachment_album_geometry.dart';
import 'attachment_image_tile.dart';
import 'media-preview/chat_media_preview_meta.dart';
import 'signal_bubble_metrics.dart';

/// Multi-image album: fills the bubble's available width × [mediaMaxHeight],
/// equal cells, row 1 then row 2, `+N` on the last cell when both rows are full.
///
/// Every image in the message stays in [gallery] whatever the cell count, so
/// overflow photos are one swipe away in the viewer.
class AttachmentImageGrid extends StatelessWidget {
  const AttachmentImageGrid({
    super.key,
    required this.images,
    this.withCaption = false,
    this.captioned = false,
    this.preview,
  });

  final List<ChatMessageAttachment> images;

  /// A picture carrying text is held to a wider floor, so the caption is not
  /// squeezed into a narrow bubble beneath it.
  final bool withCaption;

  /// Text under an edge-to-edge picture: same wider floor, no inset.
  final bool captioned;

  final ChatMediaPreviewMeta? preview;

  static const double _corner = 14;

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
        minWidth: withCaption || captioned
            ? SignalBubbleMetrics.mediaMinWidthWithCaption
            : SignalBubbleMetrics.mediaMinWidthSolo,
        preview: preview,
        inset: withCaption,
      );
    }
    return Padding(
      padding: EdgeInsets.only(top: withCaption ? 8 : 0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Use the bubble's full available width — do not clamp to the solo
          // mediaMaxWidth (240); that left empty space beside multi albums.
          final width =
              constraints.hasBoundedWidth && constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : SignalBubbleMetrics.mediaMaxWidth;
          final layout = albumLayout(
            count: images.length,
            width: width,
            corner: _corner,
            maxHeight: SignalBubbleMetrics.mediaMaxHeight,
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
