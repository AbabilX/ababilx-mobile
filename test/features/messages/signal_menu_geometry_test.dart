import 'package:ababilx/features/messages/chat-timeline/signal_message_menu_geometry.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

const _phone = Size(400, 880);
const _safe = EdgeInsets.only(top: 44, bottom: 24);
const _menu = Size(240, 350);

SignalMenuLayout _layout(Rect anchor, {bool isMine = true, Size? screen}) =>
    resolveSignalMenuLayout(
      screen: screen ?? _phone,
      safeArea: _safe,
      anchor: anchor,
      menuSize: _menu,
      isMine: isMine,
    );

void main() {
  test('menu sits under the bubble and the bar above it when there is room', () {
    final layout = _layout(const Rect.fromLTWH(200, 300, 180, 44));

    expect(layout.reversed, isFalse);
    expect(layout.scale, 1);
    expect(layout.menu.top, layout.bubble.bottom + 12);
    expect(layout.bar.bottom, lessThanOrEqualTo(layout.bubble.top));
    // Outgoing: the bar hugs the right margin, the menu the bubble's end.
    expect(layout.bar.right, _phone.width - 16);
    expect(layout.bar.width, 320);
    expect(layout.menu.right, closeTo(380, 0.01));
  });

  test('an incoming bubble anchors both pieces to the left margin', () {
    final layout = _layout(const Rect.fromLTWH(16, 300, 180, 44), isMine: false);

    expect(layout.bar.left, 16);
    expect(layout.menu.left, 16);
  });

  test('a bubble near the bottom is lifted so the menu still fits below', () {
    final layout = _layout(const Rect.fromLTWH(200, 700, 180, 44));

    // Signal moves the message rather than flipping the menu: the bubble rises
    // until menu + gap clear the navigation bar.
    expect(layout.reversed, isFalse);
    expect(layout.bubble.top, lessThan(700));
    expect(layout.menu.top, layout.bubble.bottom + 12);
    expect(layout.menu.bottom, _phone.height - _safe.bottom);
  });

  test('a bubble at the very top is pushed down to clear the bar', () {
    final layout = _layout(const Rect.fromLTWH(200, 46, 180, 44));

    // 44 status bar + 32 top padding + 56 bar + 12 gap.
    expect(layout.bubble.top, 144);
    expect(layout.bar.top, 76);
  });

  test('a bubble too tall for bar plus menu is scaled down, not covered', () {
    final layout = _layout(const Rect.fromLTWH(120, 100, 260, 600));

    expect(layout.scale, lessThan(1));
    expect(layout.bubble.height, closeTo(600 * layout.scale, 0.01));
    expect(layout.bubble.bottom + 12, closeTo(layout.menu.top, 0.01));
    expect(layout.menu.bottom, lessThanOrEqualTo(_phone.height - _safe.bottom));
    // Scaling an outgoing bubble keeps its right edge where it was.
    expect(layout.bubble.right, 380);
  });

  test('a wide screen puts the menu beside the bar, not under the bubble', () {
    final layout = _layout(
      const Rect.fromLTWH(500, 300, 180, 44),
      screen: const Size(900, 600),
    );

    expect(layout.reversed, isFalse);
    // Outgoing on a wide screen: bar right-aligned, menu to its left.
    expect(layout.bar.right, 900 - 16);
    expect(layout.menu.right, closeTo(layout.bar.left - 12, 0.01));
    expect(layout.bubble, const Rect.fromLTWH(500, 300, 180, 44));
  });
}
