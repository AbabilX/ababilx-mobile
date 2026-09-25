import 'package:ababilx/features/calls/data/models/voice_call.dart';
import 'package:ababilx/features/calls/providers/call_identity.dart';
import 'package:ababilx/features/calls/providers/voice_call_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('callIdentity', () {
    test('an empty profile id takes the call row\'s answer', () {
      expect(callIdentity('', 'me', source: 'start'), 'me');
    });

    test('the call row wins over a stale profile id', () {
      expect(callIdentity('someone-else', 'me', source: 'start'), 'me');
    });

    test('a row that names nobody keeps what the profile said', () {
      expect(callIdentity('me', '', source: 'accept'), 'me');
    });
  });

  test('a call placed with no profile loaded still counts as outgoing', () {
    final call = VoiceCall.fromJson({
      'id': 'call-1',
      'conversation_id': 'conv-1',
      'caller_id': 'me',
      'callee_id': 'peer',
      'status': 'accepted',
      'expires_at': DateTime.now().toUtc().toIso8601String(),
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
    final before = VoiceCallState(call: call);
    expect(before.outgoing, isFalse, reason: 'the bug: empty id');
    final after = VoiceCallState(
      call: call,
      currentUserId: callIdentity('', call.callerId, source: 'start'),
    );
    expect(after.outgoing, isTrue);
  });
}
