import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'call_overlay_metrics.dart';

/// Morph duration for End seat + icon glyph turns.
const callControlsOrientDuration = Duration(milliseconds: 280);

/// Where the control **seats** live — not the icon glyphs.
///
/// Portrait → bottom (home / gesture edge, opposite the camera bump).
/// Landscape → that **same physical edge** as a vertical strip: rotate the
/// phone left → strip on the right; rotate right → strip on the left.
/// Never pin to the camera/notch edge.
class CallControlsAnchor extends StatelessWidget {
  const CallControlsAnchor({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = media.size;
    final padding = media.padding;
    final landscape = size.width > size.height;
    final edge = math.max(8.0, math.max(padding.left, padding.right));
    final bottom = math.max(padding.bottom, 12.0);

    final pinRight = pinControlsToPhysicalBottom(media);
    final turns = callIconQuarterTurns(
      landscape: landscape,
      pinRight: pinRight,
    );

    final oriented = CallIconOrientation(quarterTurns: turns, child: child);

    if (!landscape) {
      return Positioned(
        left: edge,
        right: edge,
        bottom: bottom + CallOverlayMetrics.of(context).deckLift,
        child: oriented,
      );
    }

    return Positioned(
      top: padding.top + 12,
      bottom: padding.bottom + 12,
      right: pinRight ? edge : null,
      left: pinRight ? null : edge,
      child: oriented,
    );
  }
}

/// Portrait-bottom edge in landscape coordinates.
///
/// The camera/notch cutout makes the **larger** horizontal [viewPadding].
/// The home/gesture edge (where portrait controls sat) is the **smaller**
/// side — pin there. Equal insets → assume rotate-left (bottom → right).
@visibleForTesting
bool pinControlsToPhysicalBottom(MediaQueryData media) {
  final inset = media.viewPadding;
  if ((inset.left - inset.right).abs() > 0.5) {
    return inset.right <= inset.left;
  }
  return true;
}

/// Icon-only quarter-turns so glyphs stay upright relative to gravity.
int callIconQuarterTurns({required bool landscape, required bool pinRight}) {
  return 0;
}

/// Propagates icon-only rotation to [CallGlassCircle] inners.
class CallIconOrientation extends InheritedWidget {
  const CallIconOrientation({
    super.key,
    required this.quarterTurns,
    required super.child,
  });

  final int quarterTurns;

  static int of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<CallIconOrientation>()
          ?.quarterTurns ??
      0;

  @override
  bool updateShouldNotify(CallIconOrientation oldWidget) =>
      quarterTurns != oldWidget.quarterTurns;
}
