import 'package:ababilx/shared/widgets/image_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final images = [
    const PreviewImage(fileUrl: '', fileName: 'first.jpg'),
    const PreviewImage(fileUrl: '', fileName: 'second.jpg'),
  ];

  testWidgets('pinch zooms a photo while it is inside the gallery', (
    tester,
  ) async {
    await _openGallery(tester, images);
    final center = tester.getCenter(find.byType(PageView));
    final first = await tester.createGesture(pointer: 1);
    final second = await tester.createGesture(pointer: 2);
    await first.down(center + const Offset(-40, 0));
    await second.down(center + const Offset(40, 0));
    await tester.pump();
    await first.moveTo(center + const Offset(-100, 0));
    await second.moveTo(center + const Offset(100, 0));
    await tester.pump();

    expect(_scale(tester), greaterThan(1.2));
    expect(
      tester.widget<PageView>(find.byType(PageView)).controller!.page,
      closeTo(0, 0.01),
    );
    await first.up();
    await second.up();
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('pinch works when the first finger moves before the second', (
    tester,
  ) async {
    await _openGallery(tester, images);
    final center = tester.getCenter(find.byType(PageView));
    final first = await tester.createGesture(pointer: 1);
    final second = await tester.createGesture(pointer: 2);
    await first.down(center + const Offset(-40, 0));
    await first.moveBy(const Offset(-22, 0));
    await tester.pump();
    await second.down(center + const Offset(40, 0));
    await tester.pump();
    await first.moveTo(center + const Offset(-110, 0));
    await second.moveTo(center + const Offset(110, 0));
    await tester.pump();

    expect(_scale(tester), greaterThan(1.2));
    await first.up();
    await second.up();
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('panning a zoomed photo never changes photos', (tester) async {
    await _openGallery(tester, images);
    final center = tester.getCenter(find.byType(PageView));
    await tester.tapAt(center);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tapAt(center);
    await tester.pumpAndSettle();
    expect(_scale(tester), greaterThan(1.2));

    // Dragging to the right-hand edge of the photo is looking at it.
    final pan = await tester.startGesture(center);
    await pan.moveBy(const Offset(-600, 0));
    await pan.up();
    await tester.pumpAndSettle();
    expect(
      tester.widget<PageView>(find.byType(PageView)).controller!.page,
      closeTo(0, 0.01),
    );
    expect(_scale(tester), greaterThan(1.2));

    // Zoomed back out, the same swipe moves on.
    await tester.tapAt(center);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tapAt(center);
    await tester.pumpAndSettle();
    expect(_scale(tester), closeTo(1, 0.01));
    final swipe = await tester.startGesture(center);
    await swipe.moveBy(const Offset(-600, 0));
    await swipe.up();
    await tester.pumpAndSettle();
    expect(
      tester.widget<PageView>(find.byType(PageView)).controller!.page,
      closeTo(1, 0.01),
    );
  });

  testWidgets('a normal horizontal swipe changes photos', (tester) async {
    await _openGallery(tester, images);
    final swipe = await tester.startGesture(
      tester.getCenter(find.byType(PageView)),
    );
    await swipe.moveBy(const Offset(-600, 0));
    await swipe.up();
    await tester.pumpAndSettle();
    expect(
      tester.widget<PageView>(find.byType(PageView)).controller!.page,
      closeTo(1, 0.01),
    );
  });

  testWidgets('leaving a zoomed photo resets it before returning', (
    tester,
  ) async {
    await _openGallery(tester, images);
    final center = tester.getCenter(find.byType(PageView));
    await tester.tapAt(center);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tapAt(center);
    await tester.pumpAndSettle();
    expect(_scale(tester), greaterThan(1.2));

    final page = tester.widget<PageView>(find.byType(PageView));
    page.controller!.jumpToPage(1);
    await tester.pumpAndSettle();
    page.controller!.jumpToPage(0);
    await tester.pumpAndSettle();

    expect(_scale(tester), closeTo(1, 0.01));
  });

  testWidgets('zoomed photo stays inside its page', (tester) async {
    await _openGallery(tester, images);
    expect(
      tester
          .widget<InteractiveViewer>(find.byType(InteractiveViewer).first)
          .clipBehavior,
      Clip.hardEdge,
    );
  });
}

Future<void> _openGallery(
  WidgetTester tester,
  List<PreviewImage> images,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showImagePreview(
              context,
              images: images,
              initialIndex: 0,
              allowRemoteFallback: false,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

double _scale(WidgetTester tester) => tester
    .widget<InteractiveViewer>(find.byType(InteractiveViewer).first)
    .transformationController!
    .value
    .getMaxScaleOnAxis();
