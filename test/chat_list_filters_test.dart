import 'package:ababilx/features/messages/chat_list_filters.dart';
import 'package:ababilx/features/messages/data/models/chat_conversation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ChatConversation conversation({
    String? body,
    String? attachmentType,
    String? lastMessageUserId = 'me',
  }) {
    return ChatConversation(
      id: 'conversation-1',
      teamId: 'team-1',
      type: 'dm',
      createdAt: '2026-07-26T00:00:00Z',
      lastMessageBody: body,
      lastMessageUserId: lastMessageUserId,
      lastMessageAttachmentType: attachmentType,
    );
  }

  test('text preview wins over stale image metadata', () {
    final preview = previewWithYou(
      conversation(
        body:
            '{"type":"doc","content":[{"type":"paragraph","content":[{"type":"text","text":"Hello from text"}]}]}',
        attachmentType: 'image/jpeg',
      ),
      'me',
    );

    expect(preview, 'You: Hello from text');
  });

  test('other user message has no You prefix', () {
    final preview = previewWithYou(
      conversation(
        body:
            '{"type":"doc","content":[{"type":"paragraph","content":[{"type":"text","text":"evening meet join"}]}]}',
        lastMessageUserId: 'other-user',
      ),
      'me',
    );

    expect(preview, 'evening meet join');
  });

  test('empty user ids do not get You prefix', () {
    final preview = previewWithYou(
      conversation(body: 'plain hi', lastMessageUserId: ''),
      '',
    );
    expect(preview, 'plain hi');
  });

  test('conversation copy can clear previous attachment preview', () {
    final updated = conversation(body: '', attachmentType: 'image/jpeg')
        .copyWith(
          lastMessageBody: 'plain text',
          lastMessageAttachments: const [
            ChatLastAttachment(fileName: 'a.jpg', contentType: 'image/jpeg'),
          ],
          clearLastMessageAttachment: true,
        );

    expect(updated.lastMessageAttachmentType, isNull);
    expect(updated.lastMessageAttachmentName, isNull);
    expect(updated.lastMessageAttachments, isEmpty);
  });

  test('file badges come from last message attachments list', () {
    final preview = chatListPreview(
      ChatConversation(
        id: 'c1',
        teamId: 't1',
        type: 'dm',
        createdAt: '2026-07-26T00:00:00Z',
        lastMessageBody:
            '{"type":"doc","content":[{"type":"paragraph","content":[{"type":"text","text":"see files"}]}]}',
        lastMessageUserId: 'other',
        lastMessageAttachments: const [
          ChatLastAttachment(
            fileName: 'report.pdf',
            contentType: 'application/pdf',
          ),
          ChatLastAttachment(fileName: 'shot.png', contentType: 'image/png'),
        ],
      ),
      'me',
    );

    expect(preview.text, 'see files');
    expect(preview.fromMe, isFalse);
    expect(preview.files.length, 2);
    expect(preview.files.first.fileName, 'report.pdf');
  });
}
