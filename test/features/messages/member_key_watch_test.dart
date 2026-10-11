import 'dart:convert';

import 'package:ababilx/features/messages/safety_number/member_key_watch.dart';
import 'package:ababilx/features/messages/safety_number/safety_number_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The server is the only source of another member's public key. These pin
/// that the phone remembers the first one it saw for a person and reports a
/// different one, most of all when a conversation key was sealed to it.
Map<String, dynamic> _key(int seed) => {
  'kty': 'EC',
  'crv': 'P-256',
  'x': base64Url.encode(List.filled(32, seed)).replaceAll('=', ''),
  'y': base64Url.encode(List.filled(32, seed + 1)).replaceAll('=', ''),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const store = SafetyNumberStore();
  final watch = MemberKeyWatch(store);

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('the first key seen for a person is remembered', () async {
    expect(await watch.observe('me', 'peer', _key(1)), PeerTrust.firstSeen);
    expect(await watch.observe('me', 'peer', _key(1)), PeerTrust.unchanged);
  });

  test(
    'a different key later is a change, until the user has looked',
    () async {
      await watch.observe('me', 'peer', _key(1));
      expect(await watch.observe('me', 'peer', _key(2)), PeerTrust.changed);
      // Looking is the only thing that settles it: nothing was overwritten.
      expect(await watch.observe('me', 'peer', _key(2)), PeerTrust.changed);
      await store.remember(
        'me',
        'peer',
        await watch.fingerprint('peer', _key(2)),
      );
      expect(await watch.observe('me', 'peer', _key(2)), PeerTrust.unchanged);
    },
  );

  test('a key sealed to another identity stays reported when the old key '
      'is handed out again', () async {
    await watch.observe('me', 'peer', _key(1));
    expect(
      await watch.observe('me', 'peer', _key(2), sealing: true),
      PeerTrust.changed,
    );
    expect(await store.isFlagged('me', 'peer'), isTrue);
    // The server answers the next question with the remembered key.
    expect(await watch.observe('me', 'peer', _key(1)), PeerTrust.changed);

    await store.remember(
      'me',
      'peer',
      await watch.fingerprint('peer', _key(1)),
    );
    expect(await store.isFlagged('me', 'peer'), isFalse);
    expect(await watch.observe('me', 'peer', _key(1)), PeerTrust.unchanged);
  });

  test('a change seen without sealing is not flagged', () async {
    await watch.observe('me', 'peer', _key(1));
    await watch.observe('me', 'peer', _key(2));
    expect(await store.isFlagged('me', 'peer'), isFalse);
  });

  test(
    'memory is per account and per person, and never about oneself',
    () async {
      await watch.observe('me', 'peer', _key(1));
      expect(
        await watch.observe('other', 'peer', _key(2)),
        PeerTrust.firstSeen,
      );
      expect(await watch.observe('me', 'third', _key(2)), PeerTrust.firstSeen);
      expect(await watch.observe('me', 'me', _key(9)), PeerTrust.unchanged);
      expect(await watch.observe('', 'peer', _key(9)), PeerTrust.firstSeen);
    },
  );

  test('an account switch forgets flags with the fingerprints', () async {
    await watch.observe('me', 'peer', _key(1));
    await watch.observe('me', 'peer', _key(2), sealing: true);
    await store.forgetAll();
    expect(await store.isFlagged('me', 'peer'), isFalse);
    expect(await watch.observe('me', 'peer', _key(2)), PeerTrust.firstSeen);
  });
}
