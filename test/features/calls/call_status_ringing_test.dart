import 'package:ababilx/features/calls/call_status_text.dart';
import 'package:ababilx/features/calls/data/models/voice_call.dart';
import 'package:ababilx/features/calls/ongoing_call_notice.dart';
import 'package:ababilx/features/calls/providers/voice_call_state.dart';
import 'package:flutter_test/flutter_test.dart';

VoiceCall _call({DateTime? ringingAt}) => VoiceCall(
  id: 'c1',
  teamId: '',
  conversationId: 'conv',
  callerId: 'me',
  calleeId: 'peer',
  status: 'ringing',
  callerName: 'Me',
  calleeName: 'Peer',
  expiresAt: DateTime.now().add(const Duration(minutes: 1)),
  createdAt: DateTime.now(),
  calleeRingingAt: ringingAt,
);

void main() {
  test('caller says Calling until a callee device rings', () {
    final calling = VoiceCallState(
      phase: VoiceCallPhase.outgoingRinging,
      call: _call(),
      currentUserId: 'me',
    );
    expect(voiceCallStatusText(calling), 'Calling…');
    final ringing = calling.copyWith(call: _call(ringingAt: DateTime.now()));
    expect(voiceCallStatusText(ringing), 'Ringing…');
  });

  test('callee sees key exchange while the accepted call connects', () {
    final state = VoiceCallState(
      phase: VoiceCallPhase.connecting,
      call: _call(),
      currentUserId: 'peer',
    );

    expect(voiceCallStatusText(state), 'Exchanging security keys…');
  });

  test('caller keeps the general connecting message', () {
    final state = VoiceCallState(
      phase: VoiceCallPhase.connecting,
      call: _call(),
      currentUserId: 'me',
    );

    expect(voiceCallStatusText(state), 'Connecting…');
  });

  test('callee_ringing_at parses from the server row', () {
    final call = VoiceCall.fromJson({
      'id': 'c1',
      'expires_at': '2026-09-16T10:00:00Z',
      'created_at': '2026-09-16T09:59:00Z',
      'callee_ringing_at': '2026-09-16T09:59:02Z',
    });
    expect(call.calleeRingingAt, isNotNull);
    expect(call.copyWith(status: 'accepted').calleeRingingAt, isNotNull);
  });

  test('ongoing notification follows the ringing state', () {
    expect(
      ongoingCallSubtitle(VoiceCallPhase.outgoingRinging, remoteRinging: true),
      'Ringing…',
    );
    expect(ongoingCallSubtitle(VoiceCallPhase.outgoingRinging), 'Calling…');
  });
}
