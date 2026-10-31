import 'dart:math' as math;
import 'package:flutter/painting.dart';

import 'message_menu_metrics.dart';

// Re-exported so every caller keeps one import for the overlay's numbers
// and its placement.
export 'message_menu_metrics.dart';

/// Where every piece of the overlay ends up. Pure geometry — no widgets, no
/// context — so the placement rules can be tested without a device.
class MessageMenuLayout {
  const MessageMenuLayout({
    required this.bubble,
    required this.scale,
    required this.bar,
    required this.menu,
    required this.reversed,
  });

  /// Final rect of the lifted message. The reference app moves the bubble out
  /// of the way rather than letting the menu cover it.
  final Rect bubble;

  /// < 1 when the bubble had to shrink to make room for bar and menu.
  final double scale;
  final Rect bar;
  final Rect menu;

  /// The reference app reverses the item order when the menu opens upwards, so
  /// the row nearest the bubble stays the first one.
  final bool reversed;
}

/// Ports the reference app's `ConversationReactionOverlay#showAfterLayout`
/// placement.
///
/// The whole thing turns on one question — does bar + bubble + menu fit in the
/// space between the status bar and the navigation bar? If it does, the bubble
/// stays put and the menu goes below it (above it, reversed, when the bubble is
/// near the bottom). If it does not, the bubble is scaled down until it does.
/// A screen wide enough for the 320-wide bar *and* the menu side by side (a
/// tablet, or a phone in landscape) puts them side by side instead.
///
/// When the menu must open **above** the bubble (tall content / near the
/// bottom), the stack is bar → menu → bubble — never bar and menu sharing the
/// same band. Sharing that band is what clipped the reaction scrubber behind
/// the action list on a long link-preview bubble.
MessageMenuLayout resolveMessageMenuLayout({
  required Size screen,
  required EdgeInsets safeArea,
  required Rect anchor,
  required Size menuSize,
  required bool isMine,
}) {
  final top = safeArea.top;
  final bottom = screen.height - safeArea.bottom;
  final barWidth = math.min(
    MessageMenuMetrics.barWidth,
    screen.width - MessageMenuMetrics.horizontalMargin * 2,
  );
  final barLeft = isMine
      ? screen.width - barWidth - MessageMenuMetrics.horizontalMargin
      : MessageMenuMetrics.horizontalMargin;

  double menuLeft = isMine ? anchor.right - menuSize.width : anchor.left;
  menuLeft = menuLeft.clamp(
    MessageMenuMetrics.horizontalMargin,
    math.max(
      MessageMenuMetrics.horizontalMargin,
      screen.width - menuSize.width - MessageMenuMetrics.horizontalMargin,
    ),
  );

  final wide =
      menuSize.width + barWidth + MessageMenuMetrics.horizontalMargin * 3 <
      screen.width;
  if (wide) {
    final barTop = math.max(
      top + MessageMenuMetrics.barTopPadding,
      anchor.top -
          MessageMenuMetrics.menuPadding -
          MessageMenuMetrics.barHeight,
    );
    final menuTop = math.min(barTop, bottom - menuSize.height);
    return MessageMenuLayout(
      bubble: anchor,
      scale: 1,
      bar: Rect.fromLTWH(
        barLeft,
        barTop,
        barWidth,
        MessageMenuMetrics.barHeight,
      ),
      menu: Rect.fromLTWH(
        isMine
            ? barLeft - menuSize.width - MessageMenuMetrics.menuPadding
            : barLeft + barWidth + MessageMenuMetrics.menuPadding,
        math.max(top, menuTop),
        menuSize.width,
        menuSize.height,
      ),
      reversed: false,
    );
  }

  final available = bottom - top;
  // Room above the bubble when the menu opens upward: bar + gap + menu + gap.
  final aboveChrome =
      MessageMenuMetrics.barHeight +
      MessageMenuMetrics.menuPadding +
      menuSize.height +
      MessageMenuMetrics.menuPadding;
  // A short bubble cannot hold the bar off the top by itself, so the layout has
  // to reserve the difference when the menu sits below.
  final spaceForBar = math.max(
    MessageMenuMetrics.barHeight + MessageMenuMetrics.barOffset - anchor.height,
    0.0,
  );
  final fits =
      menuSize.height +
          anchor.height +
          MessageMenuMetrics.menuPadding +
          spaceForBar <
      available;

  var scale = 1.0;
  var bubbleTop = anchor.top;
  var bubbleHeight = anchor.height;

  if (fits) {
    final menuFitsBelow =
        anchor.bottom + MessageMenuMetrics.menuPadding + menuSize.height <=
        bottom;
    if (!menuFitsBelow) {
      bubbleTop =
          bottom -
          menuSize.height -
          MessageMenuMetrics.menuPadding -
          anchor.height;
    }
    bubbleTop = math.max(bubbleTop, top);
    if (bubbleTop -
            MessageMenuMetrics.menuPadding -
            MessageMenuMetrics.barHeight <
        top + MessageMenuMetrics.barTopPadding) {
      bubbleTop =
          top +
          MessageMenuMetrics.barTopPadding +
          MessageMenuMetrics.barHeight +
          MessageMenuMetrics.menuPadding;
    }
  } else {
    // Tall content: reserve space for bar+menu above OR menu below. Prefer
    // menu-below with the bar above the bubble (the common path); the reverse
    // path still needs the full aboveChrome so the scrubber is not covered.
    final roomBelow =
        available -
        menuSize.height -
        MessageMenuMetrics.menuPadding -
        spaceForBar;
    final roomAbove = available - aboveChrome;
    final room = math.max(roomBelow, roomAbove);
    scale = (room / anchor.height).clamp(0.35, 1.0);
    bubbleHeight = anchor.height * scale;
    bubbleTop = top + spaceForBar;
  }

  var bubble = Rect.fromLTWH(
    isMine ? anchor.right - anchor.width * scale : anchor.left,
    bubbleTop,
    anchor.width * scale,
    bubbleHeight,
  );

  var menuTop = bubble.bottom + MessageMenuMetrics.menuPadding;
  var reversed = false;
  if (menuTop + menuSize.height > bottom) {
    reversed = true;
    // Stack above the bubble: [bar] [gap] [menu] [gap] [bubble]. The old
    // code parked the bar on the menu's bottom edge (both ending at
    // bubble.top − gap), and clamping menuTop to the safe-area top then
    // stole the bar's lane entirely — that is the tall-content scrubber
    // clipped behind Delete/Edit.
    final minMenuTop =
        top +
        MessageMenuMetrics.barTopPadding +
        MessageMenuMetrics.barHeight +
        MessageMenuMetrics.menuPadding;
    final minBubbleTop =
        minMenuTop + menuSize.height + MessageMenuMetrics.menuPadding;
    if (bubble.top < minBubbleTop) {
      var shifted = minBubbleTop;
      if (shifted + bubble.height > bottom) {
        // Still too tall even stacked above: shrink so bar+menu+bubble fit.
        final room = bottom - minBubbleTop;
        scale = (room / anchor.height).clamp(0.35, scale);
        bubbleHeight = anchor.height * scale;
        shifted = math.min(minBubbleTop, bottom - bubbleHeight);
        bubble = Rect.fromLTWH(
          isMine ? anchor.right - anchor.width * scale : anchor.left,
          shifted,
          anchor.width * scale,
          bubbleHeight,
        );
      } else {
        bubble = Rect.fromLTWH(
          bubble.left,
          shifted,
          bubble.width,
          bubble.height,
        );
      }
    }
    menuTop = bubble.top - MessageMenuMetrics.menuPadding - menuSize.height;
    menuTop = menuTop.clamp(
      minMenuTop,
      math.max(minMenuTop, bottom - menuSize.height),
    );
  } else {
    menuTop = menuTop.clamp(top, math.max(top, bottom - menuSize.height));
  }

  final barTop = reversed
      ? math.max(
          top + MessageMenuMetrics.barTopPadding,
          menuTop -
              MessageMenuMetrics.menuPadding -
              MessageMenuMetrics.barHeight,
        )
      : math.max(
          top + MessageMenuMetrics.barTopPadding,
          bubble.top -
              MessageMenuMetrics.menuPadding -
              MessageMenuMetrics.barHeight,
        );

  return MessageMenuLayout(
    bubble: bubble,
    scale: scale,
    bar: Rect.fromLTWH(barLeft, barTop, barWidth, MessageMenuMetrics.barHeight),
    menu: Rect.fromLTWH(menuLeft, menuTop, menuSize.width, menuSize.height),
    reversed: reversed,
  );
}
