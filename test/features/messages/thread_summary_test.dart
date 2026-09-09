import 'package:ababilx/features/messages/chat-timeline/thread_people.dart';
import 'package:ababilx/features/messages/chat-timeline/thread_summary.dart';
import 'package:ababilx/features/messages/data/models/chat_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ChatMessage _message({
  required String id,
  required String userId,
  required String body,
  required String createdAt,
  String? userName,
  List<ChatMessageAttachment> attachments = const [],
}) => ChatMessage(
  id: id,
  conversationId: 'c1',
  userId: userId,
  body: body,
  createdAt: createdAt,
  userName: userName,
  attachments: attachments,
);

ChatMessageAttachment _file(String name) => ChatMessageAttachment(
  id: 'a-$name',
  messageId: 'm',
  fileName: name,
  fileUrl: 'https://cdn.example/$name',
  contentType: 'application/octet-stream',
  sizeBytes: 12,
  uploadedBy: 'u1',
  createdAt: '2026-09-01T00:00:00Z',
);

void main() {
  final root = _message(
    id: 'root',
    userId: 'alice',
    userName: 'Alice',
    body: 'This Month',
    createdAt: '2026-09-01T00:00:00Z',
  );

  group('threadPreview', () {
    test('uses the newest reply body', () {
      expect(
        threadPreview([
          _message(
            id: 'r1',
            userId: 'bob',
            body: 'older',
            createdAt: '2026-09-01T01:00:00Z',
          ),
          _message(
            id: 'r2',
            userId: 'cara',
            body: '@Tanbir 8726',
            createdAt: '2026-09-02T01:00:00Z',
          ),
        ]),
        '@Tanbir 8726',
      );
    });

    test('stays blank until replies are loaded', () {
      expect(threadPreview(const []), '');
    });

    test('names an attachment-only reply', () {
      expect(
        threadPreview([
          _message(
            id: 'r1',
            userId: 'bob',
            body: '',
            createdAt: '2026-09-01T01:00:00Z',
            attachments: [_file('doc.pdf')],
          ),
        ]),
        'Sent an attachment',
      );
    });
  });

  group('threadReplyLabel', () {
    test('names the replies, not the root plus replies', () {
      expect(threadReplyLabel(1), '1 reply');
      expect(threadReplyLabel(4), '4 replies');
    });
  });

  group('threadParticipants', () {
    test('includes the root when replies have not loaded', () {
      final people = threadParticipants(root, const []);
      expect(people, hasLength(1));
      expect(people.single.userId, 'alice');
    });

    test('keeps unique authors, newest first, capped at 3', () {
      final people = threadParticipants(root, [
        _message(
          id: 'r1',
          userId: 'bob',
          userName: 'Bob',
          body: 'hi',
          createdAt: '2026-09-01T01:00:00Z',
        ),
        _message(
          id: 'r2',
          userId: 'cara',
          userName: 'Cara',
          body: 'hey',
          createdAt: '2026-09-01T02:00:00Z',
        ),
        _message(
          id: 'r3',
          userId: 'dan',
          userName: 'Dan',
          body: 'yo',
          createdAt: '2026-09-01T03:00:00Z',
        ),
        _message(
          id: 'r4',
          userId: 'bob',
          userName: 'Bob',
          body: 'again',
          createdAt: '2026-09-01T04:00:00Z',
        ),
      ]);
      expect(people.map((p) => p.userId).toList(), ['bob', 'dan', 'cara']);
    });
  });

  testWidgets('draws a compact reply chip, not a second copy of the bubble', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ThreadSummary(
            root: root,
            replies: [
              _message(
                id: 'r1',
                userId: 'bob',
                userName: 'Bob',
                body: '@Tanbir 8726',
                createdAt: '2026-09-02T01:00:00Z',
              ),
            ],
            count: 4,
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.text('4 replies'), findsOneWidget);
    expect(find.text('@Tanbir 8726'), findsOneWidget);
    expect(find.text('This Month'), findsNothing);
    expect(find.byKey(ThreadSummary.railKey), findsOneWidget);
  });
}
