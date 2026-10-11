import 'package:ababilx/features/messages/message_e2ee/group_roster_pins.dart';
import 'package:ababilx/features/messages/message_e2ee/message_vault.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'roster_harness.dart';

/// A group's roster is the server's word. These pin the two things the phone
/// still decides: a member it first meets now gets no older key, and the user
/// is told that someone new can read the chat.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pins = GroupRosterPins();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> send(MessageVault vault, String self) =>
      vault.encryptNew(conversationId: 'chat', text: 'x', currentUserId: self);

  test('the first roster is taken as it is, a later member is new', () async {
    await pins.observe('a', 'chat', ['a', 'bob', 'carol']);
    expect(await pins.unseen('a', 'chat'), isEmpty);
    await pins.observe('a', 'chat', ['a', 'bob', 'carol', 'dave']);
    expect(await pins.unseen('a', 'chat'), ['dave']);

    // Someone here from the start may have any key back.
    expect(
      await pins.mayHandKey('a', 'chat', 'bob', version: 1, newest: 3),
      isTrue,
    );
    // Dave was met when the newest key was 3: that one and older stay closed.
    expect(
      await pins.mayHandKey('a', 'chat', 'dave', version: 3, newest: 3),
      isFalse,
    );
    expect(
      await pins.mayHandKey('a', 'chat', 'dave', version: 2, newest: 5),
      isFalse,
    );
    expect(
      await pins.mayHandKey('a', 'chat', 'dave', version: 4, newest: 5),
      isTrue,
    );
    final stored = await SharedPreferences.getInstance();
    expect(
      stored.getStringList('chat_group_roster_v1:a:chat'),
      containsAll(['bob 0 1', 'dave 3 0']),
    );
  });

  test('looking clears the notice; leaving and returning is new', () async {
    await pins.observe('b', 'chat', ['bob']);
    await pins.observe('b', 'chat', ['bob', 'dave']);
    await pins.markSeen('b', 'chat');
    expect(await pins.unseen('b', 'chat'), isEmpty);
    await pins.observe('b', 'chat', ['dave']);
    await pins.observe('b', 'chat', ['bob', 'dave']);
    expect(await pins.unseen('b', 'chat'), ['bob']);
    // Back at key 7, the keys from the first stay are not handed over again.
    expect(
      await pins.mayHandKey('b', 'chat', 'bob', version: 2, newest: 7),
      isFalse,
    );
  });

  test('a member this phone added itself raises no notice', () async {
    await pins.observe('c', 'chat', ['bob']);
    await pins.expect('c', 'chat', 'dave');
    await pins.observe('c', 'chat', ['bob', 'dave']);
    expect(await pins.unseen('c', 'chat'), isEmpty);
    // With no record yet there is nothing to expect into.
    await pins.expect('c', 'other', 'dave');
    expect(await pins.known('c', 'other'), isFalse);
  });

  test('a member added behind the group is handed no old key', () async {
    final phone = RosterPhone('d');
    final server = phone.server..rosterIds = ['d', 'bob'];
    await send(await phone.open(), 'd');
    // A row written into the database, with a join date in the past: the
    // server now says both lost key 1.
    server
      ..rosterIds = ['d', 'bob', 'ghost']
      ..gaps = {
        1: ['bob', 'ghost'],
      };
    await send(await phone.open(), 'd');
    expect(server.handed, [
      ['bob', 1],
    ]);
    expect(await pins.unseen('d', 'chat'), ['ghost']);
  });

  test('a key minted after they appeared is theirs to get back', () async {
    final phone = RosterPhone('e');
    final server = phone.server..rosterIds = ['e', 'bob'];
    final vault = await phone.open();
    await send(vault, 'e');
    server.rosterIds = ['e', 'bob', 'dave'];
    await vault.rekeyAndEncrypt(
      conversationId: 'chat',
      text: 'y',
      currentUserId: 'e',
    );
    expect(server.sealedTo[2], {'e', 'bob', 'dave'});
    expect(await pins.unseen('e', 'chat'), ['dave']);
    server.gaps = {
      1: ['dave'],
      2: ['dave'],
    };
    await send(await phone.open(), 'e');
    expect(server.handed, [
      ['dave', 2],
    ]);
  });

  test('a group first seen through a gap takes its roster as it is', () async {
    final phone = RosterPhone('f');
    final server = phone.server..rosterIds = ['f', 'bob'];
    // Sealed by the notification isolate: no record is kept.
    await send(await phone.openBare(), 'f');
    expect(await pins.known('f', 'chat'), isFalse);
    server.gaps = {
      1: ['bob'],
    };
    await send(await phone.open(), 'f');
    expect(server.handed, [
      ['bob', 1],
    ]);
    expect(await pins.unseen('f', 'chat'), isEmpty);
  });

  test('the notification isolate hands no old group key', () async {
    final phone = RosterPhone('g');
    final server = phone.server..rosterIds = ['g', 'bob'];
    await send(await phone.open(), 'g');
    server.gaps = {
      1: ['bob'],
    };
    await send(await phone.openBare(), 'g');
    expect(server.handed, isEmpty);
    // The app does, when it next runs.
    await send(await phone.open(), 'g');
    expect(server.handed, [
      ['bob', 1],
    ]);
  });
}
