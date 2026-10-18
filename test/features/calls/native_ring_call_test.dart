import 'package:ababilx/features/calls/native/native_ring_call.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 10, 18, 12);

  Map<String, dynamic> extra({
    String type = 'voice_call',
    String callId = 'call-1',
    String conversationId = 'conv-1',
    String callerId = 'alice',
    String callerName = 'Alice',
    String avatar = 'https://cdn.example/a.jpg',
    String? expiresAt,
    String mode = 'audio',
  }) => {
    'type': type,
    'call_id': callId,
    'conversation_id': conversationId,
    'caller_id': callerId,
    'caller_name': callerName,
    'caller_avatar_url': avatar,
    'expires_at':
        expiresAt ?? now.add(const Duration(seconds: 40)).toIso8601String(),
    'mode': mode,
  };

  test('a live ring record becomes a ringing call', () {
    final call = voiceCallFromNativeRing(
      extra(mode: 'video'),
      id: 'call-1',
      currentUserId: 'me',
      now: now,
    )!;
    expect(call.id, 'call-1');
    expect(call.status, 'ringing');
    expect(call.conversationId, 'conv-1');
    expect(call.callerId, 'alice');
    expect(call.calleeId, 'me');
    expect(call.isVideo, isTrue);
    expect(call.peerName('me'), 'Alice');
    expect(call.peerAvatar('me'), 'https://cdn.example/a.jpg');
  });

  test('an unknown own id still names the caller as the peer', () {
    final call = voiceCallFromNativeRing(extra(), id: 'call-1', now: now)!;
    expect(call.peerName(''), 'Alice');
    expect(call.peerId(''), 'alice');
  });

  test('a rung-out record is not a ring', () {
    expect(
      voiceCallFromNativeRing(
        extra(expiresAt: now.toIso8601String()),
        id: 'call-1',
        now: now,
      ),
      isNull,
    );
  });

  test('group rings, our own outgoing record and thin records are refused', () {
    expect(
      voiceCallFromNativeRing(
        extra(type: 'group_call'),
        id: 'call-1',
        now: now,
      ),
      isNull,
    );
    expect(
      voiceCallFromNativeRing(
        extra(callerId: 'me'),
        id: 'call-1',
        currentUserId: 'me',
        now: now,
      ),
      isNull,
    );
    expect(
      voiceCallFromNativeRing(
        extra(conversationId: ''),
        id: 'call-1',
        now: now,
      ),
      isNull,
    );
    expect(
      voiceCallFromNativeRing(
        extra(callId: 'other'),
        id: 'call-1',
        now: now,
      ),
      isNull,
    );
    expect(voiceCallFromNativeRing(null, id: 'call-1', now: now), isNull);
  });

  test('a blank name or picture falls back instead of drawing nothing', () {
    final call = voiceCallFromNativeRing(
      extra(callerName: '  ', avatar: ''),
      id: 'call-1',
      now: now,
    )!;
    expect(call.callerName, 'AbabilX call');
    expect(call.callerAvatarUrl, isNull);
  });
}
