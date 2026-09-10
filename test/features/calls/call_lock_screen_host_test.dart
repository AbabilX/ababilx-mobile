import 'package:ababilx/features/calls/providers/voice_call_state.dart';
import 'package:ababilx/features/calls/widgets/call_lock_screen_host.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  bool onTop(String path, VoiceCallPhase voice, {bool group = false}) =>
      callScreenOnTop(path: path, voice: voice, groupActive: group);

  test('a DM call screen with a call behind it may show over the lock', () {
    expect(onTop('/call', VoiceCallPhase.connecting), isTrue);
    expect(onTop('/call', VoiceCallPhase.connected), isTrue);
    expect(onTop('/call', VoiceCallPhase.incomingRinging), isTrue);
  });

  test('"Call ended" stays up for its moment, an idle screen does not', () {
    expect(onTop('/call', VoiceCallPhase.ended), isTrue);
    expect(onTop('/call', VoiceCallPhase.idle), isFalse);
  });

  test('every other route stays behind the keyguard, call or not', () {
    expect(onTop('/messages/abc', VoiceCallPhase.connected), isFalse);
    expect(onTop('/messages', VoiceCallPhase.connected, group: true), isFalse);
    expect(
      onTop('/group-call/lobby', VoiceCallPhase.idle, group: true),
      isFalse,
    );
  });

  test('a group call screen counts only while joining or connected', () {
    expect(onTop('/group-call', VoiceCallPhase.idle, group: true), isTrue);
    expect(onTop('/group-call', VoiceCallPhase.idle), isFalse);
  });
}
