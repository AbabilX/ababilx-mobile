import 'dart:ui';

import 'package:ababilx/features/messages/chat-timeline/signal_message_menu_geometry.dart';
import 'package:ababilx/features/messages/chat-timeline/signal_reaction_scrub.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // A 320-wide bar with Signal's seven slots: six emoji and "more".
  const bar = Rect.fromLTWH(16, 100, 320, SignalMenuMetrics.barHeight);
  const slots = 7;
  const segment = 320 / slots;

  // Far enough below the bar that reaching it always clears the deadzone.
  const touchDown = Offset(180, 300);

  int? selectionAt(Offset? pointer, {Offset from = touchDown}) =>
      signalScrubSelection(
        bar: bar,
        slots: slots,
        pointer: pointer,
        touchDown: from,
      );

  test('no finger means no selection', () {
    expect(selectionAt(null), isNull);
  });

  test('a finger that has not left the deadzone picks nothing', () {
    // Letting go of a long press without moving must open the menu, not react.
    expect(
      selectionAt(const Offset(180, 290), from: const Offset(180, 300)),
      isNull,
    );
  });

  test('dragging up onto a slot picks it', () {
    expect(selectionAt(Offset(bar.left + segment * 0.5, bar.top + 10)), 0);
    expect(selectionAt(Offset(bar.left + segment * 3.5, bar.top + 10)), 3);
  });

  test('the last slot is the "more" circle, not an emoji', () {
    expect(selectionAt(Offset(bar.right - 2, bar.top + 10)), slots - 1);
  });

  test('a finger below the scrub band picks nothing', () {
    // The band stops 30 below where the press landed, so wandering down the
    // conversation cannot fire a reaction.
    expect(
      selectionAt(Offset(bar.left + segment * 2, touchDown.dy + 60)),
      isNull,
    );
  });

  test('a finger past either end of the bar picks nothing', () {
    expect(selectionAt(Offset(bar.left - 4, bar.top + 10)), isNull);
    expect(selectionAt(Offset(bar.right + 4, bar.top + 10)), isNull);
  });

  test('an empty bar is never selectable', () {
    expect(
      signalScrubSelection(
        bar: Rect.zero,
        slots: slots,
        pointer: const Offset(10, 10),
        touchDown: touchDown,
      ),
      isNull,
    );
  });
}
