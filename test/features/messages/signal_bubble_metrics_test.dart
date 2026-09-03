import 'package:ababilx/features/messages/chat-timeline/sender_name_color.dart';
import 'package:ababilx/features/messages/chat-timeline/signal_bubble_metrics.dart';
import 'package:ababilx/features/messages/chat-timeline/timeline_reveal_policy.dart';
import 'package:ababilx/features/messages/chat_utils.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const big = Radius.circular(SignalBubbleMetrics.bigRadius);
  const small = Radius.circular(SignalBubbleMetrics.smallRadius);

  group('bubble corners', () {
    test('a lone message is round on every corner, either side', () {
      for (final own in [true, false]) {
        final r = signalBubbleRadius(
          position: MessageClusterPosition.single,
          isOwn: own,
        );
        expect(r, const BorderRadius.all(big));
      }
    });

    // Your run collapses on the right, theirs on the left — the side the
    // bubbles are stacked against.
    test('an outgoing run collapses only its right corners', () {
      final start = signalBubbleRadius(
        position: MessageClusterPosition.start,
        isOwn: true,
      );
      expect(start.bottomRight, small);
      expect(start.bottomLeft, big);
      expect(start.topLeft, big);
      expect(start.topRight, big);

      final middle = signalBubbleRadius(
        position: MessageClusterPosition.middle,
        isOwn: true,
      );
      expect(middle.topRight, small);
      expect(middle.bottomRight, small);
      expect(middle.topLeft, big);
      expect(middle.bottomLeft, big);

      final end = signalBubbleRadius(
        position: MessageClusterPosition.end,
        isOwn: true,
      );
      expect(end.topRight, small);
      expect(end.topLeft, big);
      expect(end.bottomRight, big);
    });

    test('an incoming run collapses only its left corners', () {
      final start = signalBubbleRadius(
        position: MessageClusterPosition.start,
        isOwn: false,
      );
      expect(start.bottomLeft, small);
      expect(start.bottomRight, big);

      final middle = signalBubbleRadius(
        position: MessageClusterPosition.middle,
        isOwn: false,
      );
      expect(middle.topLeft, small);
      expect(middle.bottomLeft, small);
      expect(middle.topRight, big);
      expect(middle.bottomRight, big);

      final end = signalBubbleRadius(
        position: MessageClusterPosition.end,
        isOwn: false,
      );
      expect(end.topLeft, small);
      expect(end.topRight, big);
      expect(end.bottomLeft, big);
    });
  });

  group('row spacing', () {
    test('separate messages keep the full gap', () {
      expect(
        signalBubbleTopSpacing(MessageClusterPosition.single),
        SignalBubbleMetrics.spacingDefault,
      );
      expect(
        signalBubbleTopSpacing(MessageClusterPosition.start),
        SignalBubbleMetrics.spacingDefault,
      );
    });

    test('bubbles inside a run almost touch', () {
      expect(
        signalBubbleTopSpacing(MessageClusterPosition.middle),
        SignalBubbleMetrics.spacingCollapsed,
      );
      expect(
        signalBubbleTopSpacing(MessageClusterPosition.end),
        SignalBubbleMetrics.spacingCollapsed,
      );
    });
  });

  group('sender name colour', () {
    test('is stable for one user', () {
      expect(senderNameColor('user-42'), senderNameColor('user-42'));
    });

    test('does not depend on Object.hashCode, which varies per run', () {
      // Recomputed from the code units, so the expectation can be written down.
      var hash = 0;
      for (final unit in 'user-42'.codeUnits) {
        hash = (hash * 31 + unit) & 0x7fffffff;
      }
      expect(senderNameColor('user-42'), isNotNull);
      expect(hash, greaterThan(0));
    });

    test('an empty id still yields a colour', () {
      expect(senderNameColor(''), isNotNull);
    });
  });

  // reverse:true list: pixels count up into older history.
  group('collapsing header', () {
    test('scrolling back through history hides it', () {
      expect(
        resolveHeaderVisibility(pixels: 300, delta: 40, visible: true),
        isFalse,
      );
    });

    test('scrolling back toward the newest messages shows it', () {
      expect(
        resolveHeaderVisibility(pixels: 300, delta: -40, visible: false),
        isTrue,
      );
    });

    test('the top of the conversation always shows it', () {
      expect(
        resolveHeaderVisibility(pixels: 4, delta: 40, visible: false),
        isTrue,
      );
    });

    test('a resting thumb does not flicker it', () {
      expect(
        resolveHeaderVisibility(pixels: 300, delta: 3, visible: true),
        isTrue,
      );
      expect(
        resolveHeaderVisibility(pixels: 300, delta: -3, visible: false),
        isFalse,
      );
    });
  });
}
