import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:open_filex/open_filex.dart';

import '../../../shared/widgets/app_toast.dart';
import '../../messages/chat-timeline/message_bubble.dart'
    show SignalBubbleColors;
import '../../messages/chat-timeline/signal_bubble_metrics.dart';
import '../../messages/chat_icon.dart';
import '../native/ghost_blobs.dart';
import '../providers/ghost_save.dart';
import '../providers/ghost_state.dart';
import '../providers/ghost_temp_files.dart';
import '../screens/ghost_pdf_viewer.dart';
import '../screens/ghost_video_viewer.dart';
import 'ghost_bubble.dart';
import 'ghost_labels.dart';

/// A file inside a Ghost Chat bubble: name, size, progress.
///
/// Tapping it depends on what the sender allowed. With saving allowed (and
/// always for the sender's own file) it goes to another app, as it always did.
/// View only, it may not leave this app at all: a PDF and a video open in
/// Ghost Chat's own viewers, from memory, and anything else cannot be opened.
class GhostFileRow extends ConsumerWidget {
  const GhostFileRow({super.key, required this.item, required this.colors});

  final GhostItem item;
  final SignalBubbleColors colors;

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final bytes = item.bytes;
    if (bytes == null || !item.complete) return;
    if (!item.mayLeaveApp) {
      if (item.isPdf) return showGhostPdf(context, item);
      if (item.isVideo) return showGhostVideo(context, item);
      showAppToast(context, ghostText(ref, 'ghost_err_view_only_type'));
      return;
    }
    // Memory first, always. A temp file is the fallback for a platform with
    // no blob provider (iOS today), and it is the one place Ghost Chat bytes
    // touch the disk — deleted on the burn and at every app start.
    final name = item.fileName ?? 'file';
    final mime = item.mime ?? 'application/octet-stream';
    if (await GhostBlobs.open(name, mime, bytes, key: item.id)) return;
    final path = await GhostTempFiles.writeForOpen(name, bytes);
    await OpenFilex.open(path, type: mime);
  }

  Future<void> _save(BuildContext context, WidgetRef ref) async {
    final ok = await saveGhostItem(item);
    if (!context.mounted) return;
    showAppToast(
      context,
      ghostText(ref, ok ? 'ghost_saved' : 'ghost_save_failed'),
      isError: !ok,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final done = item.complete && !item.failed;
    final size = _size(item.size);
    final subtitle = item.failed
        ? ghostText(ref, 'ghost_failed')
        : !done
        ? '${(item.progress * 100).round()}% · $size'
        : item.mayLeaveApp
        ? size
        : '$size · ${ghostText(ref, 'ghost_view_only')}';
    final canSave = done && !item.fromMe && item.rules.allowSave;

    return InkWell(
      onTap: done ? () => _open(context, ref) : null,
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
                      ? ChatIcon(_icon, color: colors.foreground)
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
                if (canSave)
                  IconButton(
                    onPressed: () => _save(context, ref),
                    tooltip: ghostText(ref, 'ghost_save'),
                    icon: ChatIcon(
                      HugeIcons.strokeRoundedDownload04,
                      color: colors.foreground,
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

  List<List<dynamic>> get _icon => item.isImage
      ? HugeIcons.strokeRoundedImage01
      : item.isPdf
      ? HugeIcons.strokeRoundedPdf01
      : item.isVideo
      ? HugeIcons.strokeRoundedVideo01
      : HugeIcons.strokeRoundedFile01;

  static String _size(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
