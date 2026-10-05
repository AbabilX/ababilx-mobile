import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../shared/text/byte_size.dart';
import '../../messages/chat-timeline/message_bubble.dart'
    show SignalBubbleColors;
import '../../messages/chat_icon.dart';
import '../data/share_thread_queries.dart';
import '../engine/store/share_records.dart';
import '../providers/local_share_providers.dart';
import '../share_text.dart';

/// A whole folder in one bubble: its name, how many files, how big, and one
/// bar for all of it. Tapping lists what is inside.
class ShareFolderCard extends ConsumerWidget {
  const ShareFolderCard({
    super.key,
    required this.data,
    required this.colors,
    required this.onTap,
  });

  final ShareBubbleData data;
  final SignalBubbleColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = Theme.of(context).colorScheme.primary;
    final message = data.message;
    final total = data.files.fold<int>(0, (sum, f) => sum + f.size);
    final moving =
        message.status == ShareMessageStatus.sending ||
        message.status == ShareMessageStatus.receiving;
    double? fraction;
    if (moving && total > 0) {
      final live = ref
          .watch(localShareProgressProvider(message.id))
          .valueOrNull;
      var bytes = 0;
      for (final f in data.files) {
        bytes += f.done ? f.size : (live?.fileBytes[f.id] ?? f.bytesDone);
      }
      fraction = (bytes / total).clamp(0.0, 1.0);
    }
    final count = lsText(ref, 'ls_folder_files', name: '${data.files.length}');

    return InkWell(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ChatIcon(HugeIcons.strokeRoundedFolder01, size: 34, color: accent),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message.folderName ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colors.foreground,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  fraction == null
                      ? '$count · ${formatBytes(total)}'
                      : '${(fraction * 100).round()}% · $count',
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
    );
  }
}
