import 'package:ababilx/features/messages/chat-timeline/attachment_album_geometry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const width = 210.0;

  group('albumLayout', () {
    test('draws every image up to five', () {
      for (var count = 2; count <= 5; count++) {
        final layout = albumLayout(count: count, width: width, corner: 14);
        expect(layout.cells.length, count);
        expect(layout.overflow, 0);
      }
    });

    test('six or more reuse the five-cell shape and count the rest', () {
      final layout = albumLayout(count: 8, width: width, corner: 14);
      expect(layout.cells.length, albumMaxCells);
      // The old grid showed four cells and "+4"; the album shows five and the
      // three that are actually left over.
      expect(layout.overflow, 3);
    });

    test('cells stay inside the album and never overlap', () {
      for (var count = 2; count <= 9; count++) {
        final layout = albumLayout(count: count, width: width, corner: 14);
        for (final cell in layout.cells) {
          expect(cell.rect.left, greaterThanOrEqualTo(-0.01));
          expect(cell.rect.right, lessThanOrEqualTo(width + 0.01));
          expect(cell.rect.bottom, lessThanOrEqualTo(layout.height + 0.01));
        }
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

    test('matches Signal geometry at its own album width', () {
      expect(albumLayout(count: 2, width: width, corner: 0).height, 104);
      expect(
        albumLayout(count: 3, width: width, corner: 0).height,
        closeTo(140, 1),
      );
      expect(albumLayout(count: 4, width: width, corner: 0).height, 210);
      expect(
        albumLayout(count: 5, width: width, corner: 0).height,
        closeTo(175, 1),
      );
    });

    test('only the album outline is rounded', () {
      final layout = albumLayout(count: 4, width: width, corner: 14);
      expect(layout.cells[0].radius.topLeft.x, 14);
      expect(layout.cells[0].radius.topRight.x, 0);
      expect(layout.cells[3].radius.bottomRight.x, 14);
    });
  });
}
