import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import 'bubble_metrics.dart';

/// Where each cell of an image album sits, and how its corners are cut.
///
/// Packs L→R then next row (max 2 rows). The album box is always [width] ×
/// [maxHeight] (solo media ceiling) so multi-image uses available width and
/// the same max height as a single photo — equal columns, last cell may show
/// `+N` when both rows are full.
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

/// Portrait thumb width estimate used only to decide column count.
const double _portraitAspect = 9 / 16;

AlbumLayout albumLayout({
  required int count,
  required double width,
  required double corner,
  double maxHeight = BubbleMetrics.mediaMaxHeight,
}) {
  assert(count >= 2);
  final w = width;
  final h = maxHeight;
  final c = corner;

  int colsAt(int rowCount) {
    final rowH = (h - albumGap * (rowCount - 1)) / rowCount;
    final thumbW = math.max(72.0, rowH * _portraitAspect);
    return math.max(1, (w / thumbW).floor());
  }

  final colsOne = colsAt(1);
  final colsTwo = colsAt(2);

  late final int rows;
  late final int cols;
  if (count <= colsOne || count <= colsTwo) {
    rows = 1;
    cols = count;
  } else {
    rows = 2;
    cols = colsTwo;
  }

  final slots = rows * cols;
  final visible = math.min(count, slots);
  final overflow = count - visible;
  final tileW = (w - albumGap * (cols - 1)) / cols;
  final tileH = (h - albumGap * (rows - 1)) / rows;

  final cells = <AlbumCell>[];
  for (var i = 0; i < visible; i++) {
    final row = i ~/ cols;
    final col = i % cols;
    final x = col * (tileW + albumGap);
    final y = row * (tileH + albumGap);
    cells.add(
      AlbumCell(
        index: i,
        rect: Rect.fromLTWH(x, y, tileW, tileH),
        radius: _corners(
          row: row,
          col: col,
          rows: rows,
          cols: cols,
          corner: c,
          index: i,
          visible: visible,
        ),
      ),
    );
  }

  return AlbumLayout(cells: cells, height: h, overflow: overflow);
}

/// Outer corners of the album block only — matches the reference app's outline
/// rounding.
BorderRadius _corners({
  required int row,
  required int col,
  required int rows,
  required int cols,
  required double corner,
  required int index,
  required int visible,
}) {
  final lastCol = cols - 1;
  final lastRow = rows - 1;
  final isLast = index == visible - 1;
  // When the last row is short, the last cell is the bottom-right outline.
  final bottomRight = isLast || (row == lastRow && col == lastCol);
  final bottomLeft = row == lastRow && col == 0;
  final topLeft = row == 0 && col == 0;
  final topRight = row == 0 && col == lastCol;

  return BorderRadius.only(
    topLeft: Radius.circular(topLeft ? corner : 0),
    topRight: Radius.circular(topRight ? corner : 0),
    bottomRight: Radius.circular(bottomRight ? corner : 0),
    bottomLeft: Radius.circular(bottomLeft ? corner : 0),
  );
}
