import 'package:flutter_test/flutter_test.dart';

import 'package:ababilx/features/messages/safety_number/safety_number.dart';

// The same vector is pinned in Ababil-X-frontend's safety-number.test.mjs. If
// one side changes, the other has to change with it or two people comparing
// digits across platforms see unrelated numbers.
const _alice = SafetyIdentity(
  userId: '11111111-1111-4111-8111-111111111111',
  publicKey: {
    'kty': 'EC',
    'crv': 'P-256',
    'x': 'AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8',
    'y': 'ICEiIyQlJicoKSorLC0uLzAxMjM0NTY3ODk6Ozw9Pj8',
  },
);
const _bob = SafetyIdentity(
  userId: '22222222-2222-4222-8222-222222222222',
  publicKey: {
    'kty': 'EC',
    'crv': 'P-256',
    'x': 'QEFCQ0RFRkdISUpLTE1OT1BRUlNUVVZXWFlaW1xdXl8',
    'y': 'YGFiY2RlZmdoaWprbG1ub3BxcnN0dXZ3eHl6e3x9fn8',
  },
);

const _aliceFingerprint = '368748491245674928966846753175';
const _bobFingerprint = '562881143535833004522062121746';

void main() {
  group('safety number', () {
    test('matches the cross-platform vector', () {
      expect(identityFingerprint(_alice), _aliceFingerprint);
      expect(identityFingerprint(_bob), _bobFingerprint);
      expect(
        safetyNumber(_alice, _bob),
        '$_aliceFingerprint$_bobFingerprint',
      );
    });

    test('reads the same from either side', () {
      expect(safetyNumber(_bob, _alice), safetyNumber(_alice, _bob));
    });

    test('binds the user id, not just the key', () {
      final impostor = SafetyIdentity(
        userId: _bob.userId,
        publicKey: _alice.publicKey,
      );
      expect(identityFingerprint(impostor), isNot(_aliceFingerprint));
    });

    test('changes completely when the key is substituted', () {
      final swapped = SafetyIdentity(
        userId: _alice.userId,
        publicKey: _bob.publicKey,
      );
      expect(identityFingerprint(swapped), isNot(_aliceFingerprint));
    });

    test('refuses a key that is not a P-256 point', () {
      expect(
        () => identityFingerprint(
          const SafetyIdentity(userId: 'u', publicKey: {'kty': 'EC'}),
        ),
        throwsArgumentError,
      );
    });

    test('reads in groups of five', () {
      expect(safetyNumberGroups(_aliceFingerprint), [
        '36874', '84912', '45674', '92896', '68467', '53175',
      ]);
    });
  });
}
