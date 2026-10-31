import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../messages/chat-timeline/message_bubble.dart' show BubbleColors;
import '../../messages/chat-timeline/bubble_metrics.dart';
import '../../messages/chat_utils.dart';
import '../providers/ghost_state.dart';
import 'ghost_file_content.dart';

/// One Ghost Chat message, drawn to the same measurements as the ordinary
/// timeline (`bubble_metrics.dart`): one fill for both sides, the
/// corner facing the rest of a run collapsed, 12/7 padding, and a far edge
/// that never reaches the opposite side of the screen.
///
/// What it deliberately does NOT have: selectable text, a copy action, a
/// long-press menu, delivery ticks and reactions. A Ghost Chat that reaches
/// the clipboard has outlived its burn, and nothing here is stored long enough
/// to have a delivery state worth drawing.
class GhostBubble extends ConsumerWidget {
  const GhostBubble({super.key, required this.item, required this.position});

  final GhostItem item;
  final MessageClusterPosition position;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = BubbleColors.of(
      Theme.of(context).colorScheme,
      hasWallpaper: false,
    );
    final maxWidth =
        MediaQuery.sizeOf(context).width -
        BubbleMetrics.edgeMargin -
        BubbleMetrics.listSideGutter;

    return Padding(
      padding: EdgeInsets.only(
        top: bubbleTopSpacing(position),
        left: BubbleMetrics.listSideGutter,
        right: BubbleMetrics.listSideGutter,
      ),
      child: Align(
        alignment: item.fromMe ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.background,
              borderRadius: bubbleRadius(
                position: position,
                isOwn: item.fromMe,
              ),
            ),
            child: item.isFile
                ? GhostFileContent(item: item, colors: colors)
                : _Text(item: item, colors: colors),
          ),
        ),
      ),
    );
  }
}

class _Text extends StatelessWidget {
  const _Text({required this.item, required this.colors});

  final GhostItem item;
  final BubbleColors colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: BubbleMetrics.horizontalPadding,
        vertical: BubbleMetrics.topPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            item.body ?? '',
            style: TextStyle(
              color: colors.foreground,
              fontSize: BubbleMetrics.bodyTextSize,
            ),
          ),
          GhostBubbleTime(at: item.at, colors: colors),
        ],
      ),
    );
  }
}

/// The reference app's footer, minus everything a Ghost Chat has no state for:
/// the time, and nothing else.
class GhostBubbleTime extends StatelessWidget {
  const GhostBubbleTime({
    super.key,
    required this.at,
    required this.colors,
    this.onMedia = false,
  });

  final DateTime at;
  final BubbleColors colors;

  /// On a photo there is no themed surface to read against, so the time takes
  /// its own ink — the same exception the ordinary footer makes.
  final bool onMedia;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        DateFormat('h:mm a').format(at),
        style: TextStyle(
          fontSize: BubbleMetrics.footerTextSize,
          color: onMedia ? Colors.white : colors.muted,
        ),
      ),
    );
  }
}
