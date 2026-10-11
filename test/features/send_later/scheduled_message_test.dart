import 'package:ababilx/features/messages/data/chat_send_body.dart';
import 'package:ababilx/features/messages/data/models/chat_models.dart';
import 'package:ababilx/features/messages/send-later/scheduled_message.dart';
import 'package:ababilx/features/messages/send-later/scheduled_provider.dart';
import 'package:ababilx/features/messages/send-later/send_later_flow.dart';
import 'package:ababilx/features/messages/send-later/send_later_words.dart';
import 'package:flutter_test/flutter_test.dart';

ScheduledMessage _row(
  Map<String, dynamic> request, {
  String status = 'pending',
}) => ScheduledMessage.fromJson({
  'id': 's1',
  'conversation_id': 'c1',
  'client_message_id': 'ref-1',
  'send_at': '2026-10-12T03:00:00Z',
  'status': status,
  'message': request,
});

void main() {
  // The server replays the stored body through the ordinary send handler, so
  // this shape is the send request's own. Pinned: a key renamed here is a
  // scheduled message the server refuses days later.
  test('chatSendBody is the send request', () {
    expect(
      chatSendBody(
        clientMessageId: 'ref-1',
        body: '',
        encryptedBody: 'cipher',
        encryptionNonce: 'nonce',
        encryptionVersion: 1,
        encryptionKeyVersion: 3,
        parentId: 'p1',
        quotedMessageId: 'q1',
        mentionedUserIds: const ['u2'],
        taskPriority: 'high',
        attachments: const [
          ChatAttachmentInput(
            fileUrl: 'https://cdn/x.png',
            fileName: 'x.png',
            contentType: 'image/png',
            sizeBytes: 10,
            noSave: true,
          ),
        ],
      ),
      {
        'client_message_id': 'ref-1',
        'body': '',
        'encrypted_body': 'cipher',
        'encryption_nonce': 'nonce',
        'encryption_version': 1,
        'encryption_key_version': 3,
        'parent_id': 'p1',
        'quoted_message_id': 'q1',
        'attachments': [
          {
            'file_url': 'https://cdn/x.png',
            'file_name': 'x.png',
            'content_type': 'image/png',
            'size_bytes': 10,
          },
        ],
        'mentioned_user_ids': ['u2'],
        'media_policy': {'view_seconds': null, 'allow_save': false},
        'task': {'priority': 'high'},
      },
    );
    expect(chatSendBody(clientMessageId: 'r', body: 'hi'), {
      'client_message_id': 'r',
      'body': 'hi',
    });
  });

  test('a stored request reads back as a message the vault can open', () {
    final row = _row({
      'client_message_id': 'ref-1',
      'body': '',
      'encrypted_body': 'cipher',
      'encryption_nonce': 'nonce',
      'encryption_version': 1,
      'encryption_key_version': 4,
      'attachments': [
        {
          'file_url': 'https://cdn/a.bin',
          'file_name': 'file',
          'content_type': 'application/octet-stream',
          'size_bytes': 541,
          'enc_meta': 'meta',
          'enc_nonce': 'n',
        },
      ],
    });
    final message = row.asSealedMessage('me');
    expect(message.id, 's1');
    expect(message.conversationId, 'c1');
    expect(message.userId, 'me');
    expect(message.isEncrypted, isTrue);
    expect(message.encryptionKeyVersion, 4);
    // The file's key was sealed under the body's key version; without the
    // stamp the vault would look for version 0 and open nothing.
    expect(message.attachments.single.encKeyVersion, 4);
    expect(message.attachments.single.needsKey, isTrue);
    expect(message.attachments.single.uploadedBy, 'me');
  });

  test('status and thread', () {
    expect(_row({}).failed, isFalse);
    expect(_row({}, status: 'failed').failed, isTrue);
    expect(_row({}, status: 'needs_rekey').needsReseal, isTrue);
    expect(_row({}).parentId, isNull);
    expect(_row({'parent_id': ''}).parentId, isNull);
    expect(_row({'parent_id': 't1'}).parentId, 't1');
    expect(
      _row({
        'task': {'priority': 'low'},
      }).isTask,
      isTrue,
    );
  });

  test('a composer lists only what it would send into', () {
    final main = _row({});
    final thread = _row({'parent_id': 't1'});
    expect(scheduledFor([main, thread], null), [main]);
    expect(scheduledFor([main, thread], 't1'), [thread]);
    expect(scheduledFor([main, thread], 't2'), isEmpty);
  });

  test('preview falls back to what the message carries', () {
    expect(scheduledPreview(_row({'body': 'hello'})), '');
    expect(
      scheduledPreview(
        _row({'body': 'hello'}).withOpened(
          const ChatMessage(
            id: 's1',
            conversationId: 'c1',
            userId: 'me',
            body: 'hello',
            createdAt: '',
          ),
        ),
      ),
      'hello',
    );
    expect(
      scheduledPreview(
        _row({
          'encryption_version': 1,
          'attachments': [{}, {}],
        }),
      ),
      '2 attachments',
    );
    expect(
      scheduledPreview(_row({'encryption_version': 1})),
      'Encrypted message',
    );
  });

  test('where send later is refused', () {
    ChatConversation conv({
      String type = 'dm',
      bool isSelf = false,
      bool privateChat = false,
    }) => ChatConversation.fromJson({
      'id': 'c1',
      'type': type,
      'scope': 'personal',
      'is_self': isSelf,
      'private_chat': privateChat,
    });
    expect(sendLaterRefusal(null), isNull);
    expect(sendLaterRefusal(conv()), isNull);
    expect(sendLaterRefusal(conv(type: 'group')), isNull);
    expect(sendLaterRefusal(conv(isSelf: true)), isNotNull);
    expect(sendLaterRefusal(conv(type: 'webhook')), isNotNull);
    expect(sendLaterRefusal(conv(privateChat: true)), contains('private chat'));
  });

  test('a refusal has words', () {
    for (final reason in [
      'not_a_member',
      'member_restricted',
      'blocked',
      'scheduled_gave_up',
      'something_new',
    ]) {
      expect(scheduledFailText(reason), isNotEmpty);
    }
  });
}
