import 'package:ababilx/features/messages/data/models/chat_conversation.dart';
import 'package:ababilx/features/messages/message_e2ee/encryption_pins.dart';
import 'package:ababilx/features/messages/message_e2ee/message_vault.dart';
import 'package:ababilx/features/messages/safety_number/member_key_watch.dart';
import 'package:ababilx/features/messages/safety_number/safety_number_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'roster_harness.dart';

/// An old conversation key opens history. These pin that it is not handed to
/// an identity this phone does not remember for that person until the user
/// has confirmed it — in a group and in a DM — and that a new message is
/// still sealed to it meanwhile.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const store = SafetyNumberStore();
  final watch = MemberKeyWatch(store);

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> send(MessageVault vault, String self) =>
      vault.encryptNew(conversationId: 'chat', text: 'x', currentUserId: self);

  /// Bob is known under his first key, then the server names another for
  /// him and says he lost key 1.
  Future<(RosterPhone, Map<String, dynamic>)> bobChanged(String self) async {
    final phone = RosterPhone(self);
    final server = phone.server..rosterIds = [self, 'bob'];
    await send(await phone.open(), self);
    await watch.observe(self, 'bob', server.publicKey!);
    final swapped = await strangerIdentity();
    server
      ..keys['bob'] = swapped
      ..gaps = {
        1: ['bob'],
      };
    return (phone, swapped);
  }

  test('an old group key waits until the new identity is confirmed', () async {
    final (phone, swapped) = await bobChanged('a');
    final vault = await phone.open();
    await send(vault, 'a');
    expect(phone.server.handed, isEmpty);
    // Reported in every chat with Bob, whatever the server answers later.
    expect(await store.isFlagged('a', 'bob'), isTrue);

    // "I compared them — this is Bob."
    await store.remember('a', 'bob', await watch.fingerprint('bob', swapped));
    await vault.refillKeyGaps('a');
    expect(phone.server.handed, [
      ['bob', 1],
    ]);
  });

  test('it is asked again on the next start, not dropped', () async {
    final (phone, swapped) = await bobChanged('b');
    await send(await phone.open(), 'b');
    await send(await phone.open(), 'b');
    expect(phone.server.handed, isEmpty);
    await store.remember('b', 'bob', await watch.fingerprint('bob', swapped));
    await send(await phone.open(), 'b');
    expect(phone.server.handed, [
      ['bob', 1],
    ]);
  });

  test('a DM peer whose identity changed waits the same way', () async {
    const self = 'c';
    await const DmRosterPins().observe(self, [
      ChatConversation.fromJson({
        'id': 'chat',
        'scope': 'personal',
        'type': 'dm',
        'peer_user_id': 'bob',
        'created_at': '2026-10-11T00:00:00Z',
      }),
    ]);
    final (phone, swapped) = await bobChanged(self);
    final vault = await phone.open();
    await send(vault, self);
    expect(phone.server.handed, isEmpty);
    await store.remember(self, 'bob', await watch.fingerprint('bob', swapped));
    await vault.refillKeyGaps(self);
    expect(phone.server.handed, [
      ['bob', 1],
    ]);
  });

  test('someone whose identity this phone never saw gets it back', () async {
    final phone = RosterPhone('d');
    final server = phone.server..rosterIds = ['d', 'bob'];
    await send(await phone.open(), 'd');
    server
      ..keys['bob'] = await strangerIdentity()
      ..gaps = {
        1: ['bob'],
      };
    // Trust on first use: nothing remembered, so nothing to compare with.
    await send(await phone.open(), 'd');
    expect(server.handed, [
      ['bob', 1],
    ]);
  });

  test('a new message is still sealed to the changed identity', () async {
    final (phone, _) = await bobChanged('e');
    final vault = await phone.open();
    await vault.rekeyAndEncrypt(
      conversationId: 'chat',
      text: 'y',
      currentUserId: 'e',
    );
    // Warned about, not blocked: a person who started fresh must be able to
    // read what is sent from now on.
    expect(phone.server.sealedTo[2], {'e', 'bob'});
    expect(phone.server.handed, isEmpty);
  });
}
