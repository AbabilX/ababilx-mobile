import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../shared/text/byte_size.dart';
import '../../messages/chat-timeline/message_bubble.dart'
    show SignalBubbleColors;
import '../../messages/chat_icon.dart';
import '../engine/store/share_records.dart';
import '../share_text.dart';
import 'share_file_progress.dart';

/// A document inside a bubble: glyph, name, size — and a bar while it moves.
class ShareFileRow extends ConsumerWidget {
  const ShareFileRow({
    super.key,
    required this.message,
    required this.file,
    required this.colors,
    required this.onTap,
  });

  final ShareMessageRecord message;
  final ShareFileRecord file;
  final SignalBubbleColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = Theme.of(context).colorScheme.primary;
    final fraction = shareFileFraction(ref, message, file);
    final size = formatBytes(file.size);
    final detail = fraction != null
        ? '${(fraction * 100).round()}% · $size'
        : file.status == ShareFileStatus.failed
        ? lsText(ref, 'ls_failed')
        : size;
    final openable = file.done || message.fromMe;

    return InkWell(
      onTap: openable ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: ChatIcon(_glyph(file.mime), size: 20, color: accent),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    file.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: colors.foreground,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style: TextStyle(fontSize: 12, color: colors.muted),
                  ),
                  if (fraction != null) ...[
                    const SizedBox(height: 6),
                    SizedBox(
                      width: 160,
                      child: LinearProgressIndicator(
                        value: fraction <= 0 ? null : fraction,
                        minHeight: 3,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static List<List<dynamic>> _glyph(String mime) {
    if (mime == 'application/pdf') return HugeIcons.strokeRoundedPdf01;
    if (mime.startsWith('audio/')) return HugeIcons.strokeRoundedMusicNote01;
    if (mime.startsWith('video/')) return HugeIcons.strokeRoundedVideo01;
    if (mime.startsWith('image/')) return HugeIcons.strokeRoundedImage01;
    if (mime.contains('zip') || mime.contains('compressed')) {
      return HugeIcons.strokeRoundedFileZip;
    }
    return HugeIcons.strokeRoundedFile01;
  }
}
