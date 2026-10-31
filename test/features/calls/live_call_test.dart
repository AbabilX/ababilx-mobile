import 'package:ababilx/features/calls/data/models/voice_call.dart';
import 'package:ababilx/features/calls/group/data/models/group_call.dart';
import 'package:ababilx/features/calls/group/providers/group_call_state.dart';
import 'package:ababilx/features/calls/live_call.dart';
import 'package:ababilx/features/calls/providers/voice_call_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// The reference app's busy rule: only an idle phone rings. These are the
/// phases that make this phone busy, and the ones that must not.
void main() {
  final now = DateTime(2026, 10, 2, 12);
  final dmCall = VoiceCall(
    id: 'dm-1',
    teamId: '',
    conversationId: 'c-1',
    callerId: 'a',
    calleeId: 'b',
    status: 'accepted',
    callerName: 'A',
    calleeName: 'B',
    expiresAt: now,
    createdAt: now,
  );
  final groupCall = GroupCall(
    id: 'group-1',
    teamId: '',
    conversationId: 'c-2',
    startedBy: 'a',
    starterName: 'A',
    status: 'active',
    maxParticipants: 8,
    participantCount: 2,
    startedAt: now,
  );
  const idleGroup = GroupCallState();

  VoiceCallState dm(VoiceCallPhase phase) =>
      VoiceCallState(phase: phase, call: dmCall);

  test('answering, talking and placing a call make the phone busy', () {
    for (final phase in [
      VoiceCallPhase.outgoingRinging,
      VoiceCallPhase.connecting,
      VoiceCallPhase.connected,
    ]) {
      expect(liveCallId(dm(phase), idleGroup), 'dm-1', reason: '$phase');
    }
  });

  test('a ringing call is not busy — it is the call being offered', () {
    expect(liveCallId(dm(VoiceCallPhase.incomingRinging), idleGroup), isNull);
  });

  test('idle, ended and failed calls leave the phone free to ring', () {
    for (final phase in [
      VoiceCallPhase.idle,
      VoiceCallPhase.starting,
      VoiceCallPhase.ended,
      VoiceCallPhase.failed,
    ]) {
      expect(liveCallId(dm(phase), idleGroup), isNull, reason: '$phase');
    }
  });

  test('a joined group call is busy, its lobby is not', () {
    final idleDm = const VoiceCallState();
    for (final phase in [GroupCallPhase.joining, GroupCallPhase.connected]) {
      expect(
        liveCallId(idleDm, GroupCallState(phase: phase, call: groupCall)),
        'group-1',
      );
    }
    expect(
      liveCallId(
        idleDm,
        GroupCallState(phase: GroupCallPhase.lobby, call: groupCall),
      ),
      isNull,
    );
  });

  test('the DM call wins when both exist', () {
    expect(
      liveCallId(
        dm(VoiceCallPhase.connected),
        GroupCallState(phase: GroupCallPhase.connected, call: groupCall),
      ),
      'dm-1',
    );
  });
}
