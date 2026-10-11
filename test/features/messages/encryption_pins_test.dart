import 'package:ababilx/features/attachments/crypto/sealed_upload_policy.dart';
import 'package:ababilx/features/messages/data/models/chat_conversation.dart';
import 'package:ababilx/features/messages/message_e2ee/encryption_pins.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether to seal used to be the server's answer on every send. These pin
/// that the phone's own memory of a chat being encrypted outranks it.
ChatConversation _row(String type, {bool marked = false, String id = 'c'}) =>
    ChatConversation.fromJson({
      'id': id,
      'scope': 'personal',
      'type': type,
      'name': 'N',
      'created_at': '2026-10-11T00:00:00Z',
      if (marked) 'plaintext_until_keyed': true,
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pins = EncryptionPins();
  var user = 0;
  // The store keeps a per-user copy in memory, so each test takes a new user.
  String nextUser() => 'user-${user++}';

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('what has to be sealed', () {
    test('an unpinned chat follows the list', () {
      expect(mustSealChat(pinned: false, conversation: _row('dm')), isTrue);
      expect(mustSealChat(pinned: false, conversation: _row('group')), isTrue);
      expect(
        mustSealChat(pinned: false, conversation: _row('webhook')),
        isFalse,
      );
      expect(mustSealChat(pinned: false, conversation: null), isFalse);
    });

    test('a pinned chat is sealed whatever the list calls it', () {
      expect(mustSealChat(pinned: true, conversation: _row('webhook')), isTrue);
      expect(mustSealChat(pinned: true, conversation: null), isTrue);
    });

    test('the plaintext mark is believed only before the pin', () {
      final marked = _row('group', marked: true);
      expect(mayStayPlaintext(pinned: false, conversation: marked), isTrue);
      expect(mayStayPlaintext(pinned: true, conversation: marked), isFalse);
      expect(
        mayStayPlaintext(pinned: false, conversation: _row('group')),
        isFalse,
      );
      expect(mayStayPlaintext(pinned: false, conversation: null), isFalse);
    });
  });

  group('the pin store', () {
    test('pins what a list shows as encrypted, and only that', () async {
      final me = nextUser();
      await pins.observe(me, [
        _row('dm', id: 'dm'),
        _row('group', id: 'group'),
        _row('group', id: 'unkeyed', marked: true),
        _row('webhook', id: 'feed'),
      ]);
      expect(await pins.isPinned(me, 'dm'), isTrue);
      expect(await pins.isPinned(me, 'group'), isTrue);
      expect(await pins.isPinned(me, 'unkeyed'), isFalse);
      expect(await pins.isPinned(me, 'feed'), isFalse);
      expect(await pins.pinnedAmong(me, ['dm', 'feed', 'x']), {'dm'});
    });

    test('a later list cannot unpin', () async {
      final me = nextUser();
      await pins.observe(me, [_row('dm')]);
      await pins.observe(me, [_row('webhook'), _row('group', marked: true)]);
      expect(await pins.isPinned(me, 'c'), isTrue);
    });

    test('is written to the phone and kept per account', () async {
      final me = nextUser();
      await pins.pin(me, ['a']);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('chat_sealed_conversations_v1:$me'), ['a']);
      expect(await pins.isPinned(nextUser(), 'a'), isFalse);
      expect(await pins.isPinned('', 'a'), isFalse);
    });

    test('another isolate reads it after a reload', () async {
      final me = nextUser();
      expect(await pins.isPinned(me, 'a'), isFalse);
      // Written behind this store's back, as the app isolate would.
      SharedPreferences.setMockInitialValues({
        'chat_sealed_conversations_v1:$me': ['a'],
      });
      expect(await pins.isPinned(me, 'a', reload: true), isTrue);
    });
  });

  group('file uploads', () {
    test('once told to encrypt, the account keeps encrypting', () async {
      final me = nextUser();
      expect(await pins.sealsUploads(me, enabled: false), isFalse);
      expect(await pins.sealsUploads(me, enabled: true), isTrue);
      expect(await pins.sealsUploads(me, enabled: false), isTrue);
      expect(await pins.sealsUploads(nextUser(), enabled: false), isFalse);
    });

    test('a pinned chat seals its files whatever the list says', () {
      final marked = _row('group', marked: true);
      expect(shouldSealUpload(enabled: true, conversation: marked), isFalse);
      expect(
        shouldSealUpload(enabled: true, conversation: marked, pinned: true),
        isTrue,
      );
      expect(
        shouldSealUpload(
          enabled: true,
          conversation: _row('webhook'),
          pinned: true,
        ),
        isTrue,
      );
      expect(shouldSealUpload(enabled: true, conversation: _row('dm')), isTrue);
      expect(
        shouldSealUpload(
          enabled: false,
          conversation: _row('dm'),
          pinned: true,
        ),
        isFalse,
      );
      expect(shouldSealUpload(enabled: true, conversation: null), isFalse);
    });
  });
}
