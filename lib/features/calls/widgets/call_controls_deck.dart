import 'package:flutter/material.dart';

import 'call_controls_anchor.dart';

/// How the 1:1 call's seats are arranged.
///
/// Portrait: two rows of three, [top] over [bottom], grouped in the middle
/// with [seatGap] between seats — never spread across the width. Every seat
/// is [seatWidth] wide whatever its label, so the two rows line up. Landscape: [strip] as one
/// vertical line on the physical bottom edge (the anchor picks left/right).
class CallControlsDeck extends StatelessWidget {
  const CallControlsDeck({
    super.key,
    required this.landscape,
    required this.gap,
    required this.rowGap,
    required this.seatGap,
    required this.seatWidth,
    required this.strip,
    required this.top,
    required this.bottom,
    this.header,
  });

  final bool landscape;
  final double gap;
  final double rowGap;
  final double seatGap;
  final double seatWidth;
  final List<Widget> strip;
  final List<Widget> top;
  final List<Widget> bottom;

  /// Drawn over the two rows, [rowGap] above them. Portrait only: the
  /// landscape strip is one seat wide.
  final Widget? header;

  Widget _row(List<Widget> seats) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var i = 0; i < seats.length; i++) ...[
        if (i > 0) SizedBox(width: seatGap),
        SizedBox(
          width: seatWidth,
          child: Center(child: seats[i]),
        ),
      ],
    ],
  );

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: callControlsOrientDuration,
      curve: Curves.easeOutCubic,
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      child: landscape
          ? Column(
              key: const ValueKey('deck-landscape'),
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < strip.length; i++) ...[
                  if (i > 0) SizedBox(height: gap),
                  strip[i],
                ],
              ],
            )
          : Column(
              key: const ValueKey('deck-portrait'),
              mainAxisSize: MainAxisSize.min,
              children: [
                if (header != null) ...[header!, SizedBox(height: rowGap)],
                _row(top),
                SizedBox(height: rowGap),
                _row(bottom),
              ],
            ),
    );
  }
}
