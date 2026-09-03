import 'package:flutter_test/flutter_test.dart';
import 'package:ababilx/features/calls/call_status_text.dart';
import 'package:ababilx/features/calls/providers/voice_call_state.dart';
import 'package:ababilx/features/calls/webrtc/voice_reconnect_policy.dart';

void main() {
  group('VoiceReconnectPolicy', () {
    const policy = VoiceReconnectPolicy();

    test('first attempt is immediate, later ones back off', () {
      expect(policy.delayFor(0), Duration.zero);
      expect(policy.delayFor(1), const Duration(seconds: 3));
      expect(policy.delayFor(2) > policy.delayFor(1), isTrue);
    });

    test('past the table the final delay repeats', () {
      expect(policy.delayFor(99), policy.backoff.last);
    });

    test('a negative attempt cannot produce a negative delay', () {
      expect(policy.delayFor(-1), Duration.zero);
    });

    test('a call is kept alive well past a short outage', () {
      expect(policy.exhausted(const Duration(seconds: 40)), isFalse);
      expect(policy.exhausted(const Duration(seconds: 119)), isFalse);
      expect(policy.exhausted(const Duration(seconds: 120)), isTrue);
    });
  });

  group('status text', () {
    test('a recovering call says so instead of showing a frozen timer', () {
      final state = VoiceCallState(
        phase: VoiceCallPhase.connected,
        connectedAt: DateTime.now(),
        reconnecting: true,
      );
      expect(voiceCallStatusText(state), 'Reconnecting…');
    });

    test('a healthy connected call still shows the duration', () {
      final state = VoiceCallState(
        phase: VoiceCallPhase.connected,
        connectedAt: DateTime.now(),
      );
      expect(voiceCallStatusText(state), '00:00');
    });
  });
}
