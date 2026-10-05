import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../messages/chat-timeline/message_bubble.dart'
    show SignalBubbleColors;
import '../../messages/chat-timeline/signal_bubble_metrics.dart';
import '../../messages/chat_utils.dart';
import '../data/share_thread_queries.dart';
import 'share_bubble_content.dart';

/// One Local Share message, drawn to the chat timeline's own measurements
/// (`signal_bubble_metrics.dart`): one fill for both sides, the corner facing
/// the rest of a run collapsed, and a far edge that never reaches the other
/// side of the screen.
class ShareBubble extends ConsumerWidget {
  const ShareBubble({
    super.key,
    required this.data,
    required this.position,
    required this.onLongPress,
    required this.onRetry,
  });

  final ShareBubbleData data;
  final MessageClusterPosition position;
  final VoidCallback onLongPress;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = SignalBubbleColors.of(
      Theme.of(context).colorScheme,
      hasWallpaper: false,
    );
    final fromMe = data.message.fromMe;
    final maxWidth =
        MediaQuery.sizeOf(context).width -
        SignalBubbleMetrics.edgeMargin -
        SignalBubbleMetrics.listSideGutter;
    final radius = signalBubbleRadius(position: position, isOwn: fromMe);

    return Padding(
      padding: EdgeInsets.only(
        top: signalBubbleTopSpacing(position),
        left: SignalBubbleMetrics.listSideGutter,
        right: SignalBubbleMetrics.listSideGutter,
      ),
      child: Align(
        alignment: fromMe ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Material(
            color: colors.background,
            borderRadius: radius,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onLongPress: onLongPress,
              child: ShareBubbleContent(
                data: data,
                colors: colors,
                onRetry: onRetry,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
