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
    viewport: const Size(300, 300),
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

  CropTransform wide({
    Size image = const Size(1200, 1200),
    double scale = 1,
    Offset offset = Offset.zero,
  }) => CropTransform(
    imageSize: image,
    // 3:1, the banner strip.
    viewport: const Size(300, 100),
    scale: scale,
    offset: offset,
  );

  test('a wide window covers rather than fits', () {
    // Fitting a square image into a 3:1 window by its height would leave the
    // sides empty; covering scales by the width instead.
    expect(wide().baseScale, 300 / 1200);
    expect(wide().drawnSize, const Size(300, 300));
  });

  test('a wide window can be panned vertically but not horizontally', () {
    final t = wide();
    expect(t.clamp(const Offset(999, 0)).dx, 0);
    // 300 tall over a 100 window leaves 100 of slack each way.
    expect(t.clamp(const Offset(0, 999)).dy, 100);
  });

  test('a wide source rect keeps the window aspect ratio', () {
    final source = wide().sourceRect;
    expect(source.width / source.height, closeTo(3, 1e-9));
    expect(source.center, const Offset(600, 600));
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
