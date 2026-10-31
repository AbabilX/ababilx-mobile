import 'package:flutter/material.dart';

import '../chat_utils.dart';
import 'bubble_metrics.dart';

/// The colours one bubble draws with.
///
/// **Both sides share one fill, deliberately.** The reference app paints the
/// outgoing bubble in the chat colour, but a wall of accent blocks is loud;
/// which side a message is on already says who sent it, so the quieter surface
/// is used throughout (chosen 2026-09-03). Do not reintroduce an accent
/// outgoing bubble without asking.
///
/// The surface does get more opaque once a wallpaper is set — the reference
/// app's own `conversation_item_recv_bubble_color_wallpaper` split — so text
/// keeps its contrast over a photo. Roles come from the theme, never hexes, per
/// the mobile theme rule.
class BubbleColors {
  const BubbleColors({
    required this.background,
    required this.foreground,
    required this.muted,
  });

  factory BubbleColors.of(ColorScheme colors, {required bool hasWallpaper}) =>
      BubbleColors(
        background: hasWallpaper
            ? colors.surfaceContainerHighest
            : colors.surfaceContainerHigh,
        foreground: colors.onSurface,
        muted: colors.onSurfaceVariant,
      );

  final Color background;
  final Color foreground;
  final Color muted;
}

/// One message bubble: the reference app's rounded rectangle, its collapsed
/// corner facing the rest of the cluster, capped so the far edge never reaches
/// the opposite side of the screen.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.isOwn,
    required this.clusterPosition,
    required this.colors,
    required this.child,
    this.dimmed = false,
    this.transparent = false,
  });

  final bool isOwn;
  final MessageClusterPosition clusterPosition;
  final BubbleColors colors;
  final Widget child;

  /// Sending bubbles fade, exactly as the reference app dims an unsent item.
  final bool dimmed;

  /// Image/video-only (no caption): the media is the surface — no fill behind it.
  final bool transparent;

  @override
  Widget build(BuildContext context) {
    final radius = bubbleRadius(position: clusterPosition, isOwn: isOwn);
    final width = MediaQuery.sizeOf(context).width;
    final maxWidth =
        width - BubbleMetrics.edgeMargin - BubbleMetrics.listSideGutter * 2;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: dimmed ? 0.65 : 1,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Container(
          decoration: BoxDecoration(
            color: transparent ? Colors.transparent : colors.background,
            borderRadius: radius,
          ),
          // Media fills the bubble edge to edge, so the clip is always on and
          // the padding belongs to the content — see [MessageBubbleContent].
          clipBehavior: Clip.antiAlias,
          child: child,
        ),
      ),
    );
  }
}
