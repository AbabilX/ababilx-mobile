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
  });
}
