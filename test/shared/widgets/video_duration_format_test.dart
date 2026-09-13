import 'package:ababilx/shared/widgets/video_thumb_states.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatVideoDuration', () {
    test('reads like a player, not like a timestamp', () {
      expect(formatVideoDuration(const Duration(seconds: 7)), '0:07');
      expect(formatVideoDuration(const Duration(seconds: 62)), '1:02');
      expect(
        formatVideoDuration(const Duration(minutes: 12, seconds: 5)),
        '12:05',
      );
    });

    test('grows an hours field only when there is one', () {
      expect(
        formatVideoDuration(const Duration(hours: 1, minutes: 2, seconds: 3)),
        '1:02:03',
      );
      expect(
        formatVideoDuration(const Duration(minutes: 59, seconds: 59)),
        '59:59',
      );
    });

    test('a video whose duration is unknown reads as zero, never negative', () {
      expect(formatVideoDuration(Duration.zero), '0:00');
      expect(formatVideoDuration(const Duration(seconds: -5)), '0:00');
    });
  });

  group('formatVideoRemaining', () {
    test('prefixes an en-dash and never goes negative', () {
      expect(
        formatVideoRemaining(
          const Duration(seconds: 7),
          const Duration(seconds: 70),
        ),
        '–1:03',
      );
      expect(
        formatVideoRemaining(
          const Duration(seconds: 70),
          const Duration(seconds: 70),
        ),
        '–0:00',
      );
      expect(
        formatVideoRemaining(
          const Duration(seconds: 80),
          const Duration(seconds: 70),
        ),
        '–0:00',
      );
    });
  });
}
