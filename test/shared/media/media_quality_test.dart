import 'package:ababilx/shared/media/media_quality.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MediaQuality codes', () {
    test('match the Android enum, which crosses the channel as an int', () {
      expect(MediaQuality.standard.code, 0);
      expect(MediaQuality.high.code, 1);
    });

    test('an unknown or missing code reads as Standard', () {
      // A build of the app whose native side predates the setting sends
      // nothing back; compressing is the safe reading of silence.
      expect(MediaQuality.fromCode(null), MediaQuality.standard);
      expect(MediaQuality.fromCode(7), MediaQuality.standard);
      expect(MediaQuality.fromCode(0), MediaQuality.standard);
      expect(MediaQuality.fromCode(1), MediaQuality.high);
    });
  });
}
