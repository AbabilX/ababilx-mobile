import 'package:ababilx/features/messages/chat_list_filters.dart';
import 'package:ababilx/features/messages/data/models/chat_models.dart';
import 'package:ababilx/features/messages/message_e2ee/sidebar_preview.dart';
import 'package:flutter_test/flutter_test.dart';

// The server leaves a body out of a sidebar row and of a quote once it is
// over 32 KiB sealed (`last_message_long`, `quote.long`). A sealed body cannot
// be cut to a preview, so the row says what it is instead.
ChatConversation _row(Map<String, dynamic> extra) => ChatConversation.fromJson({
  'id': 'c1',
  'type': 'dm',
  'scope': 'personal',
  'created_at': '2026-10-08T00:00:00Z',
  'last_message_at': '2026-10-08T00:00:00Z',
  'last_message_user_id': 'u2',
  'last_message_body': 'Encrypted message',
  'last_message_encryption_version': 1,
  'last_message_encryption_nonce': 'bm9uY2U',
  ...extra,
});

void main() {
  test('a long last message with nothing to open says so', () {
    final row = _row({'last_message_long': true});
    expect(row.lastMessageLong, isTrue);
    expect(hasSealedPreview(row), isFalse);
    expect(chatListPreview(row, 'me', lang: 'en').text, 'Long message');
    expect(chatListPreview(row, 'me', lang: 'bn').text, 'বড় বার্তা');
  });

  test('text this phone opened itself wins over the label', () {
    final row = _row({
      'last_message_long': true,
    }).copyWith(lastMessageBody: 'The quarterly report, in full');
    expect(row.lastMessageLong, isTrue);
    expect(
      chatListPreview(row, 'me', lang: 'en').text,
      'The quarterly report, in full',
    );
  });

  test('an ordinary sealed row is untouched', () {
    final row = _row({'last_message_encrypted_body': 'Y2lwaGVy'});
    expect(row.lastMessageLong, isFalse);
    expect(hasSealedPreview(row), isTrue);
    expect(chatListPreview(row, 'me', lang: 'en').text, 'Encrypted message');
  });

  test('the flag survives the disk copy and leaves with the message', () {
    final row = _row({'last_message_long': true});
    expect(ChatConversation.fromJson(row.toJson()).lastMessageLong, isTrue);
    expect(_row({}).toJson().containsKey('last_message_long'), isFalse);

    // A newer message arrived whole: the row is no longer about the long one.
    const next = ChatMessage(
      id: 'm2',
      conversationId: 'c1',
      userId: 'u2',
      body: 'ok',
      createdAt: '2026-10-08T00:01:00Z',
      encryptedBody: 'Y2lwaGVy',
      encryptionNonce: 'bm9uY2U',
      encryptionVersion: 1,
      encryptionKeyVersion: 1,
    );
    expect(withLastMessageCipher(row, next).lastMessageLong, isFalse);
    expect(row.withoutMessagePreview().lastMessageLong, isFalse);
  });

  test('a quote of a long original carries the flag and no body', () {
    final quote = ChatMessageQuote.fromJson({
      'message_id': 'm1',
      'user_id': 'u2',
      'encryption_nonce': 'bm9uY2U',
      'encryption_key_version': 3,
      'long': true,
    });
    expect(quote.long, isTrue);
    expect(quote.isEncrypted, isFalse);
    expect(quote.body, isEmpty);
    expect(ChatMessageQuote.fromJson(quote.toJson()).long, isTrue);
    expect(quote.copyWith(body: 'head of it').long, isTrue);
    expect(
      ChatMessageQuote.fromJson({
        'message_id': 'm1',
      }).toJson().containsKey('long'),
      isFalse,
    );
  });
}
