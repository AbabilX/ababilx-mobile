import 'package:ababilx/features/messages/chat_list_filters.dart';
import 'package:ababilx/features/messages/data/models/chat_conversation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ChatConversation conversation({String? body, String? attachmentType}) {
    return ChatConversation(
      id: 'conversation-1',
      teamId: 'team-1',
      type: 'dm',
      createdAt: '2026-07-26T00:00:00Z',
      lastMessageBody: body,
      lastMessageUserId: 'me',
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

  test('conversation copy can clear previous attachment preview', () {
    final updated = conversation(
      body: '',
      attachmentType: 'image/jpeg',
    ).copyWith(lastMessageBody: 'plain text', clearLastMessageAttachment: true);

    expect(updated.lastMessageAttachmentType, isNull);
    expect(updated.lastMessageAttachmentName, isNull);
  });
}
