import 'package:flutter/rendering.dart';

/// Where each cell of an image album sits, and how its corners are cut.
///
/// Signal's `AlbumThumbnailView`, expressed as arithmetic instead of five
/// inflated layouts: 2 side by side, 3 as one tall cell plus a stacked pair,
/// 4 as a square, 5 as two big over three small — and **six or more reuse the
/// five-cell shape with `+N` written over the last cell**. The old grid here
/// capped at four and dropped everything past it, which is why an album of
/// eight showed `+4` and no way to reach the other four.
///
/// Corners are cut so the whole album reads as one rounded block, exactly as
/// `applyCornersForSizeClass*` does — only the outer four are rounded.
class AlbumCell {
  const AlbumCell({
    required this.index,
    required this.rect,
    required this.radius,
  });

  final int index;
  final Rect rect;
  final BorderRadius radius;
}

class AlbumLayout {
  const AlbumLayout({
    required this.cells,
    required this.height,
    required this.overflow,
  });

  final List<AlbumCell> cells;
  final double height;

  /// How many images the album could not draw. `+N` goes on the last cell.
  final int overflow;
}

const double albumGap = 2;

/// Signal's cap: five cells, the fifth carrying the overflow count.
const int albumMaxCells = 5;

AlbumLayout albumLayout({
  required int count,
  required double width,
  required double corner,
}) {
  final w = width;
  final half = (w - albumGap) / 2;
  final third = (w - albumGap) / 3;
  final smallThird = (w - albumGap * 2) / 3;
  final c = corner;
  final visible = count < albumMaxCells ? count : albumMaxCells;
  final overflow = count - visible;

  List<AlbumCell> cells;
  double height;

  switch (visible) {
    case 2:
      height = half;
      cells = [
        _cell(0, 0, 0, half, height, _r(c, 0, 0, c)),
        _cell(1, half + albumGap, 0, half, height, _r(0, c, c, 0)),
      ];
    case 3:
      final small = third;
      height = small * 2 + albumGap;
      cells = [
        _cell(0, 0, 0, third * 2, height, _r(c, 0, 0, c)),
        _cell(1, third * 2 + albumGap, 0, small, small, _r(0, c, 0, 0)),
        _cell(
          2,
          third * 2 + albumGap,
          small + albumGap,
          small,
          small,
          _r(0, 0, c, 0),
        ),
      ];
    case 4:
      height = half * 2 + albumGap;
      cells = [
        _cell(0, 0, 0, half, half, _r(c, 0, 0, 0)),
        _cell(1, half + albumGap, 0, half, half, _r(0, c, 0, 0)),
        _cell(2, 0, half + albumGap, half, half, _r(0, 0, 0, c)),
        _cell(3, half + albumGap, half + albumGap, half, half, _r(0, 0, c, 0)),
      ];
    default:
      final small = smallThird;
      final top = half;
      height = top + albumGap + small;
      final bottomY = top + albumGap;
      cells = [
        _cell(0, 0, 0, half, top, _r(c, 0, 0, 0)),
        _cell(1, half + albumGap, 0, half, top, _r(0, c, 0, 0)),
        _cell(2, 0, bottomY, small, small, _r(0, 0, 0, c)),
        _cell(3, small + albumGap, bottomY, small, small, _r(0, 0, 0, 0)),
        _cell(4, (small + albumGap) * 2, bottomY, small, small, _r(0, 0, c, 0)),
      ];
  }

  return AlbumLayout(cells: cells, height: height, overflow: overflow);
}

AlbumCell _cell(
  int index,
  double x,
  double y,
  double w,
  double h,
  BorderRadius radius,
) => AlbumCell(index: index, rect: Rect.fromLTWH(x, y, w, h), radius: radius);

BorderRadius _r(double tl, double tr, double br, double bl) =>
    BorderRadius.only(
      topLeft: Radius.circular(tl),
      topRight: Radius.circular(tr),
      bottomRight: Radius.circular(br),
      bottomLeft: Radius.circular(bl),
    );
