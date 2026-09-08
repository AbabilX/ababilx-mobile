import 'dart:ui';

import 'package:ababilx/features/calls/widgets/video_fit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('videoDisplaySize', () {
    const phone = Size(1080, 2160); // portrait call screen
    const theater = Size(1200, 700); // desktop call window

    test('same orientation fills the box', () {
      // A phone calling a phone: portrait into portrait, crop freely.
      expect(videoDisplaySize(phone, 720 / 1280), phone);
      // A laptop camera in a desktop theater.
      expect(videoDisplaySize(theater, 1280 / 720), theater);
    });

    test('landscape camera in a portrait screen is capped, not sliced', () {
      final size = videoDisplaySize(phone, 1280 / 720);
      // Full width, so nothing is cropped horizontally beyond the cap...
      expect(size.width, phone.width);
      // ...and the height shrinks to letterbox the rest, instead of the
      // frame being blown up until only a slice of it is on screen.
      expect(size.height, lessThan(phone.height));
      // Exactly 56.25% of the frame stays visible — libwebrtc's balanced
      // fraction, which is what Signal draws.
      final visible = (size.width / size.height) / (1280 / 720);
      expect(visible, closeTo(0.5625, 0.001));
    });

    test('portrait camera in a landscape window is capped too', () {
      final size = videoDisplaySize(theater, 720 / 1280);
      expect(size.height, theater.height);
      expect(size.width, lessThan(theater.width));
    });

    test('degenerate input returns the box rather than a zero-sized video', () {
      expect(videoDisplaySize(Size.zero, 1.777), Size.zero);
      expect(videoDisplaySize(phone, 0), phone);
      expect(videoDisplaySize(phone, -1), phone);
    });
  });
}
