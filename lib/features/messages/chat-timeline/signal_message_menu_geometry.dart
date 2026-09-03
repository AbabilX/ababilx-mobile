import 'dart:math' as math;
import 'package:flutter/painting.dart';

/// Signal's own measurements for the long-press overlay, in logical pixels
/// (Android dp and Flutter lp are the same unit).
///
/// Sources, for anyone checking the numbers against the reference checkout:
/// `reaction_scrubber_width` 320, `conversation_reaction_scrub_horizontal_margin`
/// 16, the scrubber background is `?attr/actionBarSize` tall with a 30dp
/// corner, `signal_context_menu` has `minWidth` 200 and an 18dp corner, and its
/// rows are a 24dp icon with 16dp side padding and 13dp above and below.
class SignalMenuMetrics {
  const SignalMenuMetrics._();

  static const barWidth = 320.0;
  static const barHeight = 56.0;
  static const barRadius = 30.0;
  static const barTopPadding = 32.0;

  /// Gap Signal leaves between the bubble and the bar it floats above.
  static const barOffset = 48.0;

  /// The one padding used between every pair of overlay pieces.
  static const menuPadding = 12.0;
  static const horizontalMargin = 16.0;

  static const menuMinWidth = 200.0;
  static const menuRadius = 18.0;
  static const menuRowHeight = 50.0;
  static const menuIconSize = 24.0;
  static const menuRowPadding = 16.0;
  static const menuIconGap = 16.0;

  static const revealDuration = Duration(milliseconds: 200);
  static const revealOffset = Duration(milliseconds: 100);
  static const hideDuration = Duration(milliseconds: 150);
  static const emojiRiseFrom = 25.0;
}

/// Where every piece of the overlay ends up. Pure geometry — no widgets, no
/// context — so the placement rules can be tested without a device.
class SignalMenuLayout {
  const SignalMenuLayout({
    required this.bubble,
    required this.scale,
    required this.bar,
    required this.menu,
    required this.reversed,
  });

  /// Final rect of the message snapshot. Signal moves the bubble out of the
  /// way rather than letting the menu cover it.
  final Rect bubble;

  /// < 1 when the bubble had to shrink to make room for bar and menu.
  final double scale;
  final Rect bar;
  final Rect menu;

  /// Signal reverses the item order when the menu opens upwards, so the row
  /// nearest the bubble stays the first one.
  final bool reversed;
}

/// Ports Signal's `ConversationReactionOverlay#showAfterLayout` placement.
///
/// The whole thing turns on one question — does bar + bubble + menu fit in the
/// space between the status bar and the navigation bar? If it does, the bubble
/// stays put and the menu goes below it (above it, reversed, when the bubble is
/// near the bottom). If it does not, the bubble is scaled down until it does.
/// A screen wide enough for the 320-wide bar *and* the menu side by side (a
/// tablet, or a phone in landscape) puts them side by side instead.
SignalMenuLayout resolveSignalMenuLayout({
  required Size screen,
  required EdgeInsets safeArea,
  required Rect anchor,
  required Size menuSize,
  required bool isMine,
}) {
  final top = safeArea.top;
  final bottom = screen.height - safeArea.bottom;
  final barWidth = math.min(
    SignalMenuMetrics.barWidth,
    screen.width - SignalMenuMetrics.horizontalMargin * 2,
  );
  final barLeft = isMine
      ? screen.width - barWidth - SignalMenuMetrics.horizontalMargin
      : SignalMenuMetrics.horizontalMargin;

  double menuLeft = isMine ? anchor.right - menuSize.width : anchor.left;
  menuLeft = menuLeft.clamp(
    SignalMenuMetrics.horizontalMargin,
    math.max(SignalMenuMetrics.horizontalMargin, screen.width - menuSize.width - SignalMenuMetrics.horizontalMargin),
  );

  final wide = menuSize.width + barWidth + SignalMenuMetrics.horizontalMargin * 3 < screen.width;
  if (wide) {
    final barTop = math.max(top + SignalMenuMetrics.barTopPadding, anchor.top - SignalMenuMetrics.menuPadding - SignalMenuMetrics.barHeight);
    final menuTop = math.min(barTop, bottom - menuSize.height);
    return SignalMenuLayout(
      bubble: anchor,
      scale: 1,
      bar: Rect.fromLTWH(barLeft, barTop, barWidth, SignalMenuMetrics.barHeight),
      menu: Rect.fromLTWH(
        isMine ? barLeft - menuSize.width - SignalMenuMetrics.menuPadding : barLeft + barWidth + SignalMenuMetrics.menuPadding,
        math.max(top, menuTop),
        menuSize.width,
        menuSize.height,
      ),
      reversed: false,
    );
  }

  final available = bottom - top;
  // A short bubble cannot hold the bar off the top by itself, so the layout has
  // to reserve the difference.
  final spaceForBar = math.max(SignalMenuMetrics.barHeight + SignalMenuMetrics.barOffset - anchor.height, 0.0);
  final fits =
      menuSize.height + anchor.height + SignalMenuMetrics.menuPadding + spaceForBar < available;

  var scale = 1.0;
  var bubbleTop = anchor.top;
  var bubbleHeight = anchor.height;

  if (fits) {
    final menuFitsBelow =
        anchor.bottom + SignalMenuMetrics.menuPadding + menuSize.height <= bottom;
    if (!menuFitsBelow) {
      bubbleTop = bottom - menuSize.height - SignalMenuMetrics.menuPadding - anchor.height;
    }
    bubbleTop = math.max(bubbleTop, top);
    if (bubbleTop - SignalMenuMetrics.menuPadding - SignalMenuMetrics.barHeight < top + SignalMenuMetrics.barTopPadding) {
      bubbleTop = top + SignalMenuMetrics.barTopPadding + SignalMenuMetrics.barHeight + SignalMenuMetrics.menuPadding;
    }
  } else {
    final room = available - menuSize.height - SignalMenuMetrics.menuPadding - spaceForBar;
    scale = (room / anchor.height).clamp(0.35, 1.0);
    bubbleHeight = anchor.height * scale;
    bubbleTop = top + spaceForBar;
  }

  final bubble = Rect.fromLTWH(
    isMine ? anchor.right - anchor.width * scale : anchor.left,
    bubbleTop,
    anchor.width * scale,
    bubbleHeight,
  );
  final barTop = math.max(
    top + SignalMenuMetrics.barTopPadding,
    bubble.top - SignalMenuMetrics.menuPadding - SignalMenuMetrics.barHeight,
  );
  var menuTop = bubble.bottom + SignalMenuMetrics.menuPadding;
  var reversed = false;
  if (menuTop + menuSize.height > bottom) {
    menuTop = bubble.top - SignalMenuMetrics.menuPadding - menuSize.height;
    reversed = true;
  }
  menuTop = menuTop.clamp(top, math.max(top, bottom - menuSize.height));

  return SignalMenuLayout(
    bubble: bubble,
    scale: scale,
    bar: Rect.fromLTWH(barLeft, barTop, barWidth, SignalMenuMetrics.barHeight),
    menu: Rect.fromLTWH(menuLeft, menuTop, menuSize.width, menuSize.height),
    reversed: reversed,
  );
}
