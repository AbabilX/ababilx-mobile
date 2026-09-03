import 'package:ababilx/features/messages/chat-timeline/composer_reply_target.dart';
import 'package:ababilx/features/messages/data/models/chat_models.dart';
import 'package:flutter_test/flutter_test.dart';

ChatMessage _message({
  String id = 'm1',
  String userId = 'alice',
  String? userName = 'Alice',
  String body = 'hello',
  List<ChatMessageAttachment> attachments = const [],
}) => ChatMessage(
  id: id,
  conversationId: 'conversation-1',
  userId: userId,
  userName: userName,
  body: body,
  attachments: attachments,
  createdAt: '2026-09-03T10:00:00Z',
);

void main() {
  test('no reply and no thread sends a plain message', () {
    final target = ComposerReplyTarget.resolve(
      replyTo: null,
      threadRootId: null,
    );
    expect(target.parentId, isNull);
    expect(target.quotedMessageId, isNull);
    expect(target.preview, isNull);
  });

  test('a reply in the main timeline is a quote, never a thread parent', () {
    final target = ComposerReplyTarget.resolve(
      replyTo: _message(),
      threadRootId: null,
    );
    expect(target.quotedMessageId, 'm1');
    // The load-bearing half: parent_id would take the reply out of the main
    // feed, which the server lists with `parent_id IS NULL`.
    expect(target.parentId, isNull);
    expect(target.preview?.userName, 'Alice');
    expect(target.preview?.body, 'hello');
  });

  test(
    'inside a thread the reply belongs to the thread and carries no quote',
    () {
      final target = ComposerReplyTarget.resolve(
        replyTo: _message(),
        threadRootId: 'root-1',
      );
      expect(target.parentId, 'root-1');
      expect(target.quotedMessageId, isNull);
      expect(target.preview, isNull);
    },
  );

  test('a thread root wins even with a reply target selected', () {
    final target = ComposerReplyTarget.resolve(
      replyTo: _message(id: 'other'),
      threadRootId: 'root-1',
    );
    expect(target.parentId, 'root-1');
    expect(target.quotedMessageId, isNull);
  });

  test('quoting an attachment carries its type so the preview can name it', () {
    final target = ComposerReplyTarget.resolve(
      replyTo: _message(
        body: '',
        attachments: const [
          ChatMessageAttachment(
            id: 'a1',
            messageId: 'm1',
            fileName: 'cat.png',
            fileUrl: 'https://example.test/cat.png',
            contentType: 'image/png',
            sizeBytes: 10,
            uploadedBy: 'alice',
            createdAt: '2026-09-03T10:00:00Z',
          ),
        ],
      ),
      threadRootId: null,
    );
    expect(target.preview?.attachmentType, 'image/png');
    expect(target.preview?.isImage, isTrue);
  });
}
