import 'package:ababilx/features/calls/group/call-ui/ring_picker_sheet.dart';
import 'package:ababilx/features/calls/group/data/models/group_call.dart';
import 'package:ababilx/features/calls/group/providers/group_call_invites.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _json({Object? ring}) => {
  'id': 'call-1',
  'conversation_id': 'conv-1',
  'started_by': 'starter',
  'status': 'live',
  'started_at': DateTime.now().toUtc().toIso8601String(),
  'ring': ?ring,
};

void main() {
  group('GroupCall.ring (server 0172)', () {
    test('absent means ring, as every older server sends', () {
      expect(GroupCall.fromJson(_json()).ring, isNull);
    });

    test('false and true round-trip', () {
      expect(GroupCall.fromJson(_json(ring: false)).ring, isFalse);
      expect(GroupCall.fromJson(_json(ring: true)).ring, isTrue);
    });

    test('a non-bool is ignored, never read as false', () {
      expect(GroupCall.fromJson(_json(ring: 'false')).ring, isNull);
    });
  });

  test('a call that does not ring this account offers no invite', () {
    GroupCall? shown;
    final invites = GroupCallInvites(
      onChanged: (call) => shown = call,
      onExpired: (_) {},
    );
    invites.offer(GroupCall.fromJson(_json(ring: false)), currentUserId: 'me');
    expect(shown, isNull);
    expect(invites.invite, isNull);
  });

  group('ringSummary', () {
    test('no pick or a full pick is everyone', () {
      expect(ringSummary(null, 3), 'Everyone');
      expect(ringSummary({'a', 'b', 'c'}, 3), 'Everyone');
    });

    test('counts people, empty is nobody', () {
      expect(ringSummary({}, 3), 'Nobody');
      expect(ringSummary({'a'}, 3), '1 person');
      expect(ringSummary({'a', 'b'}, 3), '2 people');
    });
  });
}
