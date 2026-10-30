import 'package:ababilx/features/calls/webrtc/voice_audio_cap.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

void main() {
  group('reading the report', () {
    test('only the voice stream counts', () {
      final stats = [
        StatsReport('v', 'remote-inbound-rtp', 0, {
          'kind': 'video',
          'fractionLost': 0.5,
        }),
        StatsReport('a', 'remote-inbound-rtp', 0, {
          'kind': 'audio',
          'fractionLost': 0.1,
        }),
      ];
      expect(audioRemoteLossPercent(stats), closeTo(10, 0.001));
    });

    test('nothing reported is unknown, not zero', () {
      expect(audioRemoteLossPercent(const []), isNull);
    });

    test('nonsense is not a reading', () {
      for (final bad in [double.nan, double.infinity, -1.0, 'x', null]) {
        final stats = [
          StatsReport('a', 'remote-inbound-rtp', 0, {
            'kind': 'audio',
            'fractionLost': bad,
          }),
        ];
        expect(audioRemoteLossPercent(stats), isNull, reason: '$bad');
      }
    });
  });
}
