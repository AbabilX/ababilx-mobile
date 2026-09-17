import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:open_filex/open_filex.dart';

import '../../messages/chat-timeline/message_bubble.dart'
    show SignalBubbleColors;
import '../../messages/chat-timeline/signal_bubble_metrics.dart';
import '../../messages/chat_icon.dart';
import '../native/ghost_blobs.dart';
import '../providers/ghost_state.dart';
import '../providers/ghost_temp_files.dart';
import 'ghost_bubble.dart';
import 'ghost_labels.dart';

/// A photo or a file inside a Ghost Chat bubble, at the timeline's own media
/// measurements. A photo draws straight from memory; anything else is a row
/// that hands the bytes to another app to open.
class GhostFileContent extends ConsumerWidget {
  const GhostFileContent({super.key, required this.item, required this.colors});

  final GhostItem item;
  final SignalBubbleColors colors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (item.isImage && item.complete) {
      return _Photo(item: item, colors: colors);
    }
    return _FileRow(item: item, colors: colors);
  }
}

class _Photo extends StatelessWidget {
  const _Photo({required this.item, required this.colors});

  final GhostItem item;
  final SignalBubbleColors colors;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(SignalBubbleMetrics.bigRadius);
    return ClipRRect(
      borderRadius: radius,
      child: Stack(
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: SignalBubbleMetrics.mediaMaxHeight,
            ),
            child: Image.memory(
              item.bytes!,
              width: SignalBubbleMetrics.mediaMaxWidth,
              fit: BoxFit.cover,
              // Decoded at display size, so the image cache never holds a
              // full-resolution copy the burn would have to chase.
              cacheWidth:
                  (SignalBubbleMetrics.mediaMaxWidth *
                          MediaQuery.devicePixelRatioOf(context))
                      .round(),
              gaplessPlayback: true,
            ),
          ),
          // The photo is the surface: the time sits on it, as it does in the
          // ordinary timeline, with no strip and no scrim under it.
          Positioned(
            right: 8,
            bottom: 4,
            child: GhostBubbleTime(at: item.at, colors: colors, onMedia: true),
          ),
        ],
      ),
    );
  }
}

class _FileRow extends ConsumerWidget {
  const _FileRow({required this.item, required this.colors});

  final GhostItem item;
  final SignalBubbleColors colors;

  /// Memory first, always. A temp file is the fallback for a platform with no
  /// blob provider (iOS today), and it is the one place Ghost Chat bytes touch
  /// the disk — deleted on the burn and at every app start.
  Future<void> _open() async {
    final bytes = item.bytes;
    if (bytes == null || !item.complete) return;
    final name = item.fileName ?? 'file';
    final mime = item.mime ?? 'application/octet-stream';
    if (await GhostBlobs.open(name, mime, bytes)) return;
    final path = await GhostTempFiles.writeForOpen(name, bytes);
    await OpenFilex.open(path, type: mime);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final done = item.complete && !item.failed;
    final subtitle = item.failed
        ? ghostText(ref, 'ghost_failed')
        : done
        ? _size(item.size)
        : '${(item.progress * 100).round()}% · ${_size(item.size)}';

    return InkWell(
      onTap: done ? _open : null,
      borderRadius: BorderRadius.circular(SignalBubbleMetrics.bigRadius),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: SignalBubbleMetrics.horizontalPadding,
          vertical: SignalBubbleMetrics.topPadding,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox.square(
                  dimension: 40,
                  child: done || item.failed
                      ? ChatIcon(
                          item.isImage
                              ? HugeIcons.strokeRoundedImage01
                              : HugeIcons.strokeRoundedFile01,
                          color: colors.foreground,
                        )
                      : CircularProgressIndicator(
                          value: item.progress,
                          strokeWidth: 2.5,
                        ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.fileName ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.foreground,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(color: colors.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            GhostBubbleTime(at: item.at, colors: colors),
          ],
        ),
      ),
    );
  }

  static String _size(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
