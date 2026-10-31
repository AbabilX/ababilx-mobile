import 'package:flutter/material.dart';

import '../../messages/chat-timeline/bubble_metrics.dart';
import '../data/share_thread_queries.dart';
import '../engine/store/share_records.dart';
import 'share_media_tile.dart';

/// One picture at its own shape, or up to four squares with "+N" on the last.
class ShareMediaGrid extends StatelessWidget {
  const ShareMediaGrid({
    super.key,
    required this.data,
    required this.media,
    required this.onOpen,
  });

  final ShareBubbleData data;
  final List<ShareFileRecord> media;
  final void Function(ShareFileRecord file) onOpen;

  @override
  Widget build(BuildContext context) {
    const maxWidth = BubbleMetrics.mediaMaxWidth;
    if (media.length == 1) {
      final file = media.first;
      final w = file.width, h = file.height;
      final ratio = (w != null && h != null) ? (w / h).clamp(0.57, 1.9) : 1.0;
      final height = (maxWidth / ratio).clamp(
        BubbleMetrics.mediaMinWidthSolo,
        BubbleMetrics.mediaMaxHeight,
      );
      return ShareMediaTile(
        message: data.message,
        file: file,
        width: maxWidth,
        height: height,
        onTap: () => onOpen(file),
      );
    }
    const gap = 2.0;
    const cell = (maxWidth - gap) / 2;
    final shown = media.take(4).toList();
    final hidden = media.length - shown.length;
    return SizedBox(
      width: maxWidth,
      child: Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (var i = 0; i < shown.length; i++)
            Stack(
              children: [
                ShareMediaTile(
                  message: data.message,
                  file: shown[i],
                  width: shown.length == 3 && i == 2 ? maxWidth : cell,
                  height: cell,
                  onTap: () => onOpen(shown[i]),
                ),
                if (hidden > 0 && i == shown.length - 1)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ColoredBox(
                        color: const Color(0x99000000),
                        child: Center(
                          child: Text(
                            '+$hidden',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
