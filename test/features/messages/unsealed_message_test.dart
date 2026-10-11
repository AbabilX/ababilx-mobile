import 'package:ababilx/features/messages/data/models/chat_message.dart';
import 'package:ababilx/features/messages/message_e2ee/message_vault.dart';
import 'package:ababilx/features/messages/message_e2ee/sealed_since.dart';
import 'package:ababilx/features/messages/message_e2ee/unsealed_message.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'roster_harness.dart';

int _ms(String iso) => DateTime.parse(iso).millisecondsSinceEpoch;

ChatMessage _row({
  String body = 'send me the money',
  String at = '2026-10-11T10:00:00Z',
  String type = 'text',
  String sender = 'bob',
  bool sealed = false,
  String? deletedAt,
  MessageSendStatus status = MessageSendStatus.sent,
}) => ChatMessage(
  id: 'm',
  conversationId: 'chat',
  userId: sender,
  body: body,
  createdAt: at,
  messageType: type,
  deletedAt: deletedAt,
  sendStatus: status,
  encryptedBody: sealed ? 'AAAA' : null,
  encryptionNonce: sealed ? 'AAAA' : null,
  encryptionVersion: sealed ? 1 : null,
  encryptionKeyVersion: sealed ? 1 : null,
);

/// Plain text cannot reach a sealed chat through the app. These pin which
/// rows the timeline marks "Not encrypted", and where the line comes from.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const lines = SealedSince();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('plain text in a DM is marked, whenever it was sent', () {
    expect(isUnsealedText(_row(), 0), isTrue);
    expect(isUnsealedText(_row(at: '2020-01-01T00:00:00Z'), 0), isTrue);
    // TipTap JSON is text too.
    const doc =
        '{"type":"doc","content":[{"type":"paragraph","content":'
        '[{"type":"text","text":"hi"}]}]}';
    expect(isUnsealedText(_row(body: doc), 0), isTrue);
  });

  test('in a group, only after a sealed message this phone opened', () {
    final line = _ms('2026-10-01T00:00:00Z');
    expect(isUnsealedText(_row(at: '2026-10-02T00:00:00Z'), line), isTrue);
    // History from before the group had a key is ordinary plain text.
    expect(isUnsealedText(_row(at: '2026-09-30T00:00:00Z'), line), isFalse);
    // No sealed message opened yet: no line, nothing marked.
    expect(isUnsealedText(_row(), null), isFalse);
    expect(isUnsealedText(_row(at: 'not a time'), line), isFalse);
  });

  test('what the app or the server writes by design is never marked', () {
    expect(isUnsealedText(_row(sealed: true), 0), isFalse);
    expect(isUnsealedText(_row(type: 'system'), 0), isFalse);
    expect(isUnsealedText(_row(type: 'voice_call'), 0), isFalse);
    expect(isUnsealedText(_row(type: 'group_call'), 0), isFalse);
    expect(isUnsealedText(_row(type: 'webhook', sender: ''), 0), isFalse);
    // A file sent from the web has no text and is a plain object anyway.
    expect(isUnsealedText(_row(body: ''), 0), isFalse);
    expect(isUnsealedText(_row(body: '   '), 0), isFalse);
    expect(isUnsealedText(_row(deletedAt: '2026-10-11T10:01:00Z'), 0), isFalse);
    for (final status in [
      MessageSendStatus.sending,
      MessageSendStatus.uploading,
      MessageSendStatus.failed,
    ]) {
      expect(isUnsealedText(_row(status: status), 0), isFalse);
    }
  });

  test('the line only moves back, and is kept', () async {
    expect(await lines.since('a', 'chat'), isNull);
    await lines.note('a', 'chat', '2026-10-05T00:00:00Z');
    await lines.note('a', 'chat', '2026-10-09T00:00:00Z');
    expect(await lines.since('a', 'chat'), _ms('2026-10-05T00:00:00Z'));
    await lines.note('a', 'chat', '2026-10-02T00:00:00Z');
    await lines.note('a', 'chat', '');
    expect(await lines.since('a', 'chat'), _ms('2026-10-02T00:00:00Z'));
    expect(await lines.since('a', 'other'), isNull);
    final stored = await SharedPreferences.getInstance();
    expect(stored.getStringList('chat_sealed_since_v1:a'), [
      'chat ${_ms('2026-10-02T00:00:00Z')}',
    ]);
  });

  Future<ChatMessage> sealed(MessageVault vault, String self, String at) async {
    final payload = await vault.encryptNew(
      conversationId: 'chat',
      text: 'real',
      currentUserId: self,
    );
    return ChatMessage(
      id: 'm-$at',
      conversationId: 'chat',
      userId: self,
      body: '',
      createdAt: at,
      encryptedBody: payload.encryptedBody,
      encryptionNonce: payload.nonce,
      encryptionVersion: 1,
      encryptionKeyVersion: payload.keyVersion,
    );
  }

  test('a message that opens sets the line; one that does not, never', () async {
    final phone = RosterPhone('b')..server.rosterIds = ['b', 'bob'];
    final vault = await phone.open();
    final real = await sealed(vault, 'b', '2026-10-03T00:00:00Z');
    // Ciphertext the server made up, dated long ago to move the line.
    final forged = real.copyWith(encryptedBody: 'AAAAAAAAAAAAAAAAAAAAAAAA');
    final opened = await vault.decryptMessage(
      ChatMessage.fromJson({
        ...forged.toJson(),
        'created_at': '2020-01-01T00:00:00Z',
      }),
      'b',
    );
    expect(opened.body, 'Unable to decrypt this message');
    await pumpEventQueue();
    expect(await lines.since('b', 'chat'), isNull);

    expect((await vault.decryptMessage(real, 'b')).body, 'real');
    await pumpEventQueue();
    expect(await lines.since('b', 'chat'), _ms('2026-10-03T00:00:00Z'));
  });

  test('the notification isolate keeps no line', () async {
    final phone = RosterPhone('c')..server.rosterIds = ['c', 'bob'];
    final vault = await phone.openBare();
    final real = await sealed(vault, 'c', '2026-10-03T00:00:00Z');
    expect((await vault.decryptMessage(real, 'c')).body, 'real');
    await pumpEventQueue();
    expect(await lines.since('c', 'chat'), isNull);
  });
}
