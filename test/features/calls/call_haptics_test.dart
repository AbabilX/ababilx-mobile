import 'package:ababilx/features/calls/call_haptics.dart';
import 'package:ababilx/features/calls/data/models/voice_call.dart';
import 'package:ababilx/features/calls/providers/voice_call_state.dart';
import 'package:flutter_test/flutter_test.dart';

VoiceCall _call({String id = 'c1', String status = 'ringing'}) => VoiceCall(
  id: id,
  teamId: '',
  conversationId: 'conv',
  callerId: 'caller',
  calleeId: 'callee',
  status: status,
  callerName: 'A',
  calleeName: 'B',
  expiresAt: DateTime(2026),
  createdAt: DateTime(2026),
);

VoiceCallState _state(
  VoiceCallPhase phase, {
  VoiceCall? call,
  String me = 'callee',
  bool muted = false,
}) => VoiceCallState(
  phase: phase,
  call: call,
  currentUserId: me,
  muted: muted,
);

void main() {
  test('connecting -> connected buzzes once', () {
    final call = _call(status: 'accepted');
    expect(
      voiceCallHaptic(
        _state(VoiceCallPhase.connecting, call: call),
        _state(VoiceCallPhase.connected, call: call),
      ),
      CallHaptic.connected,
    );
    expect(
      voiceCallHaptic(
        _state(VoiceCallPhase.connected, call: call),
        _state(VoiceCallPhase.connected, call: call),
      ),
      isNull,
    );
  });

  test('a decline is ours on the callee, the peer on the caller', () {
    final ringing = _call();
    final declined = _call(status: 'declined');
    expect(
      voiceCallHaptic(
        _state(VoiceCallPhase.incomingRinging, call: ringing),
        _state(VoiceCallPhase.incomingRinging, call: declined),
      ),
      CallHaptic.declined,
    );
    expect(
      voiceCallHaptic(
        _state(VoiceCallPhase.outgoingRinging, call: ringing, me: 'caller'),
        _state(VoiceCallPhase.outgoingRinging, call: declined, me: 'caller'),
      ),
      CallHaptic.peerDeclined,
    );
    // Already declined: the phase moving to ended is not a second buzz.
    expect(
      voiceCallHaptic(
        _state(VoiceCallPhase.incomingRinging, call: declined),
        _state(VoiceCallPhase.ended, call: declined),
      ),
      isNull,
    );
  });

  test('mute and unmute on the same call; a new call is no press', () {
    final call = _call(status: 'accepted');
    expect(
      voiceCallHaptic(
        _state(VoiceCallPhase.connected, call: call),
        _state(VoiceCallPhase.connected, call: call, muted: true),
      ),
      CallHaptic.mute,
    );
    expect(
      voiceCallHaptic(
        _state(VoiceCallPhase.connected, call: call, muted: true),
        _state(VoiceCallPhase.connected, call: call),
      ),
      CallHaptic.unmute,
    );
    expect(
      voiceCallHaptic(
        _state(VoiceCallPhase.connected, call: call, muted: true),
        _state(VoiceCallPhase.outgoingRinging, call: _call(id: 'c2')),
      ),
      isNull,
    );
  });
}
