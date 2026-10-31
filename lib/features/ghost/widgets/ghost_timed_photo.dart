import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../messages/chat-timeline/message_bubble.dart' show BubbleColors;
import '../../messages/chat-timeline/bubble_metrics.dart';
import '../../messages/chat_icon.dart';
import '../providers/ghost_state.dart';
import '../screens/ghost_photo_viewer.dart';
import 'ghost_bubble.dart';
import 'ghost_labels.dart';

/// A timed photo as the list shows it — never the picture itself.
///
/// Receiving phone: "Photo · 5 seconds / Tap to view" until opened. Both
/// phones after that: "Viewed" / "Opened", with nothing behind it. There is no
/// thumbnail on purpose — a blurred preview is still a copy of the picture
/// that outlives its timer.
class GhostTimedPhoto extends ConsumerWidget {
  const GhostTimedPhoto({super.key, required this.item, required this.colors});

  final GhostItem item;
  final BubbleColors colors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expired = item.expired;
    final ready = !expired && item.complete && !item.failed;
    final title = expired
        ? ghostText(
            ref,
            item.fromMe ? 'ghost_photo_opened' : 'ghost_photo_viewed',
          )
        : '${ghostText(ref, 'ghost_photo')} · '
              '${ghostTimerLabel(ref, item.rules.timer)}';
    final subtitle = expired
        ? null
        : item.failed
        ? ghostText(ref, 'ghost_failed')
        : ready
        ? ghostText(ref, 'ghost_tap_to_view')
        : '${(item.progress * 100).round()}%';

    return InkWell(
      onTap: ready ? () => showGhostPhoto(context, item) : null,
      borderRadius: BorderRadius.circular(BubbleMetrics.bigRadius),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: BubbleMetrics.horizontalPadding,
          vertical: BubbleMetrics.topPadding,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox.square(
                  dimension: 32,
                  child: ready || expired || item.failed
                      ? ChatIcon(
                          expired
                              ? HugeIcons.strokeRoundedViewOff
                              : HugeIcons.strokeRoundedTimer02,
                          color: expired ? colors.muted : colors.foreground,
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
                        title,
                        style: TextStyle(
                          color: expired ? colors.muted : colors.foreground,
                          fontWeight: FontWeight.w600,
                          fontStyle: expired ? FontStyle.italic : null,
                        ),
                      ),
                      if (subtitle != null)
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
}
