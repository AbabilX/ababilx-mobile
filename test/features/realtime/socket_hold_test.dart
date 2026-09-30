import 'package:ababilx/features/calls/group/providers/group_call_state.dart';
import 'package:ababilx/features/calls/providers/voice_call_state.dart';
import 'package:ababilx/features/realtime/socket_hold.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  bool held({
    VoiceCallPhase voice = VoiceCallPhase.idle,
    GroupCallPhase group = GroupCallPhase.idle,
    bool ghost = false,
  }) =>
      socketHeldInBackground(voice: voice, group: group, ghostInSession: ghost);

  test('nothing live: the socket may go', () {
    expect(held(), isFalse);
    expect(held(voice: VoiceCallPhase.ended), isFalse);
    expect(held(voice: VoiceCallPhase.failed), isFalse);
    expect(held(group: GroupCallPhase.failed), isFalse);
  });

  test('every live 1:1 phase holds it — signalling rides the socket', () {
    for (final phase in [
      VoiceCallPhase.starting,
      VoiceCallPhase.outgoingRinging,
      VoiceCallPhase.incomingRinging,
      VoiceCallPhase.connecting,
      VoiceCallPhase.connected,
    ]) {
      expect(held(voice: phase), isTrue, reason: phase.name);
    }
  });

  test('a group call from lobby to connected holds it', () {
    for (final phase in [
      GroupCallPhase.lobby,
      GroupCallPhase.joining,
      GroupCallPhase.connected,
    ]) {
      expect(held(group: phase), isTrue, reason: phase.name);
    }
  });

  test('a Ghost Chat session holds it', () {
    expect(held(ghost: true), isTrue);
  });
}
