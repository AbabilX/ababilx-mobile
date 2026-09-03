import 'dart:ui';

import 'package:ababilx/shared/media/crop_transform.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  CropTransform transform({
    Size image = const Size(1000, 600),
    double scale = 1,
    Offset offset = Offset.zero,
  }) => CropTransform(
    imageSize: image,
    viewport: 300,
    scale: scale,
    offset: offset,
  );

  test('the shorter edge fills the window at scale 1', () {
    final t = transform();
    expect(t.baseScale, 300 / 600);
    expect(t.drawnSize.height, 300);
    expect(t.drawnSize.width, 500);
  });

  test('panning cannot expose a gap', () {
    final t = transform();
    // 500 wide over a 300 window leaves 100 of slack each way.
    expect(t.clamp(const Offset(999, 0)).dx, 100);
    expect(t.clamp(const Offset(-999, 0)).dx, -100);
    // The short edge exactly fills, so there is nowhere to move vertically.
    expect(t.clamp(const Offset(0, 50)).dy, 0);
  });

  test('a square image at scale 1 cannot be panned at all', () {
    final t = transform(image: const Size(400, 400));
    expect(t.clamp(const Offset(80, 80)), Offset.zero);
  });

  test('zooming in creates room to pan', () {
    final t = transform(image: const Size(400, 400), scale: 2);
    expect(t.clamp(const Offset(999, 999)), const Offset(150, 150));
  });

  test('the source rect is the region under the window', () {
    final t = transform(image: const Size(1000, 600));
    final source = t.sourceRect;
    expect(source.width, 600);
    expect(source.height, 600);
    expect(source.center, const Offset(500, 300));
  });

  test('panning right moves the source rect left', () {
    final t = transform(
      image: const Size(1000, 600),
      offset: const Offset(50, 0),
    );
    // 50 logical px at 0.5 scale is 100 image px.
    expect(t.sourceRect.center.dx, 400);
  });

  test('scale is clamped to the allowed range', () {
    expect(
      transform(scale: 99).effectiveScale,
      transform(scale: 6).effectiveScale,
    );
    expect(
      transform(scale: 0.1).effectiveScale,
      transform(scale: 1).effectiveScale,
    );
  });
}
