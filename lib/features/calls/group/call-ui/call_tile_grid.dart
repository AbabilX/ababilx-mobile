import 'package:flutter/material.dart';

import 'call_surface.dart';

/// Participant tiles laid out to fill the stage.
///
/// A `GridView` with a fixed `childAspectRatio` sizes its rows from the tile
/// width alone and then stops, so a call that under-fills the grid left a band
/// of dead space beneath it — most visibly a solo call, which drew one tile of
/// screen-width × 1.11 and roughly 185dp of nothing under it. Dividing the
/// height that is actually available is what removes that, and laying the rows
/// out by hand is what lets a short final row centre instead of hugging the
/// left edge.
class CallTileGrid extends StatelessWidget {
  const CallTileGrid({
    super.key,
    required this.count,
    required this.tileBuilder,
  });

  final int count;
  final Widget Function(int index) tileBuilder;

  static const double _gap = 10;

  /// Below this a tile is too short to read a name in, so the grid gives up on
  /// fitting and scrolls at a square aspect instead of squashing every tile.
  static const double _minTileHeight = 132;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final columns = callGridColumns(count);
    final rows = (count / columns).ceil();

    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth =
            (constraints.maxWidth - (columns - 1) * _gap) / columns;
        final tileHeight = (constraints.maxHeight - (rows - 1) * _gap) / rows;

        if (!constraints.maxHeight.isFinite || tileHeight < _minTileHeight) {
          return GridView.builder(
            padding: EdgeInsets.zero,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              childAspectRatio: 1,
              crossAxisSpacing: _gap,
              mainAxisSpacing: _gap,
            ),
            itemCount: count,
            itemBuilder: (_, index) => tileBuilder(index),
          );
        }

        return Column(
          children: [
            for (var row = 0; row < rows; row++) ...[
              if (row > 0) const SizedBox(height: _gap),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  // A tile draws its own background and sizes to its content,
                  // so the default `center` collapsed every one of them to
                  // zero height and the stage came up blank.
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var column = 0; column < columns; column++)
                      if (row * columns + column < count) ...[
                        if (column > 0) const SizedBox(width: _gap),
                        SizedBox(
                          width: tileWidth,
                          child: tileBuilder(row * columns + column),
                        ),
                      ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
