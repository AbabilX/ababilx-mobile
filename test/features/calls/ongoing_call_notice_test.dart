import 'package:ababilx/features/calls/ongoing_call_notice.dart';
import 'package:ababilx/features/calls/providers/voice_call_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ongoing call notification copy', () {
    test('an incoming ring gets no tray entry — CallKit owns that surface', () {
      expect(ongoingCallSubtitle(VoiceCallPhase.incomingRinging), isNull);
    });

    test('ringing out and connecting do get one, since the plugin no longer '
        'posts its own', () {
      expect(ongoingCallSubtitle(VoiceCallPhase.outgoingRinging), 'Calling…');
      expect(ongoingCallSubtitle(VoiceCallPhase.connecting), 'Connecting…');
      expect(ongoingCallSubtitle(VoiceCallPhase.connected), 'Ongoing call');
    });

    test('terminal and idle phases clear it', () {
      for (final phase in [
        VoiceCallPhase.idle,
        VoiceCallPhase.starting,
        VoiceCallPhase.ended,
        VoiceCallPhase.failed,
      ]) {
        expect(ongoingCallSubtitle(phase), isNull, reason: phase.name);
      }
    });

    test('only a connected call counts time', () {
      expect(ongoingCallUsesChronometer(VoiceCallPhase.connected), isTrue);
      expect(
        ongoingCallUsesChronometer(VoiceCallPhase.outgoingRinging),
        isFalse,
      );
      expect(ongoingCallUsesChronometer(VoiceCallPhase.connecting), isFalse);
    });

    test('foreground start retries back off with a ceiling', () {
      expect(ongoingCallRetryDelay(0), const Duration(seconds: 2));
      expect(ongoingCallRetryDelay(1), const Duration(seconds: 5));
      expect(ongoingCallRetryDelay(2), const Duration(seconds: 15));
      expect(ongoingCallRetryDelay(3), const Duration(seconds: 30));
      expect(ongoingCallRetryDelay(20), const Duration(seconds: 30));
    });
  });
}
