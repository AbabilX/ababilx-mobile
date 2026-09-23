import 'package:flutter/widgets.dart';

/// Whether a media tile can change height now without shoving what the
/// reader is looking at. [tile] and [viewport] are global rects; [direction]
/// is the list's scroll direction (`up` for the reverse chat timeline).
///
/// A row that changes extent moves only the rows AFTER it in scroll order.
/// So the one unsafe place is the leading side of the viewport — below it in
/// the reverse chat list — where a growing row pushes every visible row. A
/// tile wholly past the trailing edge moves nothing on screen, even mid-fling.
/// A tile on screen moves only the rows beyond it, which is the same thing a
/// new message arriving does; it waits for the list to stop, so a fling
/// never feels a row resize under the finger.
bool canResizeMediaFrame({
  required AxisDirection direction,
  required Rect tile,
  required Rect viewport,
  required bool scrolling,
}) {
  const slop = 0.5;
  final (inLeading, pastTrailing) = switch (direction) {
    AxisDirection.up => (
      tile.bottom > viewport.bottom + slop,
      tile.bottom <= viewport.top + slop,
    ),
    AxisDirection.down => (
      tile.top < viewport.top - slop,
      tile.top >= viewport.bottom - slop,
    ),
    AxisDirection.left => (
      tile.right > viewport.right + slop,
      tile.right <= viewport.left + slop,
    ),
    AxisDirection.right => (
      tile.left < viewport.left - slop,
      tile.left >= viewport.right - slop,
    ),
  };
  if (pastTrailing) return true;
  return !inLeading && !scrolling;
}
