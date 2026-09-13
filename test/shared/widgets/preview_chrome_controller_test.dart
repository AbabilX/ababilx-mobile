import 'package:ababilx/shared/widgets/preview_chrome_controller.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('idle hides the bars', () {
    fakeAsync((async) {
      final chrome = PreviewChrome(
        idle: const Duration(seconds: 3),
        onChanged: () {},
      );
      chrome.reveal();
      expect(chrome.visible, isTrue);
      async.elapse(const Duration(seconds: 3));
      expect(chrome.visible, isFalse);
      chrome.dispose();
    });
  });

  test('scroll forward hides, reverse shows', () {
    final chrome = PreviewChrome(idle: Duration.zero, onChanged: () {});
    chrome.reveal();
    chrome.onScroll(
      UserScrollNotification(
        metrics: const FixedScrollMetrics(
          minScrollExtent: 0,
          maxScrollExtent: 200,
          pixels: 40,
          viewportDimension: 100,
          axisDirection: AxisDirection.down,
          devicePixelRatio: 1,
        ),
        context: _FakeContext(),
        direction: ScrollDirection.forward,
      ),
    );
    expect(chrome.visible, isFalse);
    chrome.onScroll(
      UserScrollNotification(
        metrics: const FixedScrollMetrics(
          minScrollExtent: 0,
          maxScrollExtent: 200,
          pixels: 10,
          viewportDimension: 100,
          axisDirection: AxisDirection.down,
          devicePixelRatio: 1,
        ),
        context: _FakeContext(),
        direction: ScrollDirection.reverse,
      ),
    );
    expect(chrome.visible, isTrue);
    chrome.dispose();
  });

  test('content pan hides', () {
    final chrome = PreviewChrome(idle: Duration.zero, onChanged: () {});
    chrome.reveal();
    chrome.onContentPan();
    expect(chrome.visible, isFalse);
    chrome.dispose();
  });
}

class _FakeContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
