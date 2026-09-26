import 'package:ababilx/features/messages/data/models/chat_attachment.dart';
import 'package:ababilx/features/messages/data/models/chat_conversation.dart';
import 'package:ababilx/features/messages/data/models/chat_message.dart';
import 'package:ababilx/features/messages/data/models/chat_reaction.dart';
import 'package:ababilx/features/private-chat/private_chat_preview.dart';
import 'package:ababilx/features/private-chat/private_custody_media.dart';
import 'package:ababilx/features/private-chat/private_op.dart';
import 'package:ababilx/features/private-chat/private_quote.dart';
import 'package:flutter_test/flutter_test.dart';

ChatMessage _msg({
  String id = 'm1',
  String user = 'alice',
  String conv = 'c1',
}) => ChatMessage(
  id: id,
  conversationId: conv,
  userId: user,
  body: 'hi',
  createdAt: '2026-09-26T10:00:00Z',
  privateChat: true,
);

PrivateOp _op(
  String kind, {
  String sender = 'alice',
  String conv = 'c1',
  String at = '',
}) => PrivateOp(
  id: 'op1',
  conversationId: conv,
  senderId: sender,
  kind: kind,
  targetMessageId: 'm1',
  emoji: '👍',
  reacted: true,
  encryptedBody: 'sealed',
  createdAt: at,
);

void main() {
  group('private op authorship (server cannot check a purged target)', () {
    test('only the author edits or deletes', () {
      expect(
        privateOpEffect(_op(PrivateOp.edit), _msg()),
        PrivateOpEffect.edit,
      );
      expect(
        privateOpEffect(_op(PrivateOp.delete), _msg()),
        PrivateOpEffect.delete,
      );
      expect(
        privateOpEffect(_op(PrivateOp.edit, sender: 'mallory'), _msg()),
        PrivateOpEffect.ignore,
      );
      expect(
        privateOpEffect(_op(PrivateOp.delete, sender: 'mallory'), _msg()),
        PrivateOpEffect.ignore,
      );
    });

    test('an older edit never overwrites a newer one', () {
      final edited = _msg().copyWith(editedAt: '2026-09-27T10:00:00Z');
      expect(
        privateOpEffect(
          _op(PrivateOp.edit, at: '2026-09-27T09:59:59Z'),
          edited,
        ),
        PrivateOpEffect.ignore,
      );
      expect(
        privateOpEffect(
          _op(PrivateOp.edit, at: '2026-09-27T10:00:01Z'),
          edited,
        ),
        PrivateOpEffect.edit,
      );
    });

    test('anyone in the chat reacts; nothing crosses conversations', () {
      expect(
        privateOpEffect(_op(PrivateOp.reaction, sender: 'bob'), _msg()),
        PrivateOpEffect.react,
      );
      expect(
        privateOpEffect(_op(PrivateOp.reaction, conv: 'c2'), _msg()),
        PrivateOpEffect.ignore,
      );
    });
  });

  group('applyPrivateReaction', () {
    test('adds, is idempotent, and removes', () {
      var r = applyPrivateReaction(
        const [],
        userId: 'bob',
        currentUserId: 'alice',
        emoji: '👍',
        reacted: true,
      );
      expect(r.single.count, 1);
      expect(r.single.reactedByMe, isFalse);
      r = applyPrivateReaction(
        r,
        userId: 'bob',
        currentUserId: 'alice',
        emoji: '👍',
        reacted: true,
      );
      expect(r.single.count, 1, reason: 'a replayed op changes nothing');
      r = applyPrivateReaction(
        r,
        userId: 'alice',
        currentUserId: 'alice',
        emoji: '👍',
        reacted: true,
      );
      expect(r.single.count, 2);
      expect(r.single.reactedByMe, isTrue);
      r = applyPrivateReaction(
        r,
        userId: 'bob',
        currentUserId: 'alice',
        emoji: '👍',
        reacted: false,
      );
      r = applyPrivateReaction(
        r,
        userId: 'alice',
        currentUserId: 'alice',
        emoji: '👍',
        reacted: false,
      );
      expect(r, isEmpty);
    });

    test('leaves other emoji alone', () {
      final r = applyPrivateReaction(
        const [
          ChatReactionGroup(
            emoji: '❤️',
            count: 1,
            users: [ChatReactionUser(userId: 'bob')],
          ),
        ],
        userId: 'bob',
        currentUserId: 'alice',
        emoji: '👍',
        reacted: true,
      );
      expect(r.map((g) => g.emoji), ['❤️', '👍']);
    });
  });

  test('an unopened timed photo holds custody; an expired one does not', () {
    ChatMessageAttachment photo({int? seconds, bool expired = false}) =>
        ChatMessageAttachment(
          id: 'a',
          messageId: 'm1',
          fileName: 'p.jpg',
          fileUrl: 'https://cdn/x.jpg',
          contentType: 'image/jpeg',
          sizeBytes: 1,
          uploadedBy: 'alice',
          createdAt: '',
          viewSeconds: seconds,
          expired: expired,
        );
    expect(privateMediaHoldsCustody(photo(seconds: 0)), isTrue);
    expect(privateMediaHoldsCustody(photo(seconds: 0, expired: true)), isFalse);
    expect(privateMediaHoldsCustody(photo()), isFalse);
  });

  test('a purged newest message keeps the preview drawn on this phone', () {
    const old = ChatConversation(
      id: 'c1',
      teamId: '',
      createdAt: '',
      type: 'dm',
      lastMessageBody: 'see you at 5',
      lastMessageUserId: 'bob',
    );
    const fresh = ChatConversation(
      id: 'c1',
      teamId: '',
      createdAt: '',
      type: 'dm',
      lastMessagePrivate: true,
      privateChat: true,
    );
    final out = keepPrivatePreviews([fresh], [old]).single;
    expect(out.lastMessageBody, 'see you at 5');
    expect(out.privateChat, isTrue);
    const ordinary = ChatConversation(
      id: 'c1',
      teamId: '',
      createdAt: '',
      type: 'dm',
      lastMessageBody: 'new',
    );
    expect(
      keepPrivatePreviews([ordinary], [old]).single.lastMessageBody,
      'new',
    );
  });

  test('a private quote is built from the stored original', () {
    final quote = quoteOf(_msg());
    expect(quote.messageId, 'm1');
    expect(quote.userId, 'alice');
    expect(quote.body, 'hi');
  });
}
