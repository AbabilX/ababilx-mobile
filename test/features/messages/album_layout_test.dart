import 'package:ababilx/features/messages/chat-timeline/attachment_album_geometry.dart';
import 'package:ababilx/features/messages/chat-timeline/bubble_metrics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const width = 240.0;
  const maxH = BubbleMetrics.mediaMaxHeight;

  group('albumLayout', () {
    test('uses full available width and solo max height', () {
      for (var count = 2; count <= 6; count++) {
        final layout = albumLayout(
          count: count,
          width: width,
          corner: 14,
          maxHeight: maxH,
        );
        expect(layout.height, maxH);
        for (final cell in layout.cells) {
          expect(cell.rect.left, greaterThanOrEqualTo(-0.01));
          expect(cell.rect.right, lessThanOrEqualTo(width + 0.01));
          expect(cell.rect.bottom, lessThanOrEqualTo(maxH + 0.01));
        }
      }
    });

    test('one row when everything fits — full height cells', () {
      final layout = albumLayout(
        count: 2,
        width: width,
        corner: 0,
        maxHeight: maxH,
      );
      expect(layout.cells.length, 2);
      expect(layout.overflow, 0);
      expect(layout.cells[0].rect.height, maxH);
      expect(
        layout.cells[0].rect.width + layout.cells[1].rect.width,
        closeTo(width - albumGap, 0.01),
      );
    });

    test('overflow past two full rows shows +N', () {
      final layout = albumLayout(
        count: 20,
        width: width,
        corner: 14,
        maxHeight: maxH,
      );
      expect(layout.overflow, greaterThan(0));
      expect(layout.cells.length, lessThan(20));
    });

    test('cells never overlap', () {
      for (var count = 2; count <= 12; count++) {
        final layout = albumLayout(
          count: count,
          width: width,
          corner: 14,
          maxHeight: maxH,
        );
        for (var a = 0; a < layout.cells.length; a++) {
          for (var b = a + 1; b < layout.cells.length; b++) {
            final overlap = layout.cells[a].rect.intersect(
              layout.cells[b].rect,
            );
            expect(overlap.width <= 0.01 || overlap.height <= 0.01, isTrue);
          }
        }
      }
    });

    test('only the album outline is rounded', () {
      final layout = albumLayout(
        count: 4,
        width: width,
        corner: 14,
        maxHeight: maxH,
      );
      expect(layout.cells[0].radius.topLeft.x, 14);
      expect(layout.cells[0].radius.topRight.x, 0);
    });
  });
}
