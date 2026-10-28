import 'package:ababilx/features/messages/chat-timeline/message_bubble_content.dart';
import 'package:ababilx/features/messages/chat-timeline/pending_message_attachments.dart';
import 'package:ababilx/features/messages/chat-timeline/pending_upload_ring.dart';
import 'package:ababilx/features/messages/data/models/chat_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ChatAttachmentInput _file(String name, String type) => ChatAttachmentInput(
  fileUrl: 'https://cdn.example/$name',
  fileName: name,
  contentType: type,
  sizeBytes: 2400,
);

ChatMessage _pending(
  List<ChatAttachmentInput> attachments, {
  String body = '',
}) => ChatMessage(
  id: 'm1',
  conversationId: 'c1',
  userId: 'u1',
  body: body,
  createdAt: '2026-10-28T00:00:00.000Z',
  sendStatus: MessageSendStatus.uploading,
  pendingAttachments: attachments,
);

Future<void> _pump(WidgetTester tester, PendingMessageAttachments child) {
  return tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
}

void main() {
  test('a pending photo is the bubble, a document is not', () {
    expect(
      isBareMediaBubble(_pending([_file('holiday.jpg', 'image/jpeg')])),
      isTrue,
    );
    expect(
      isBareMediaBubble(
        _pending([_file('notes.pdf', 'application/pdf')], body: 'see'),
      ),
      isFalse,
    );
    expect(
      isBareMediaBubble(_pending([_file('notes.pdf', 'application/pdf')])),
      isFalse,
    );
  });

  testWidgets('upload keeps the preview and a round cancel control', (
    tester,
  ) async {
    var cancelled = 0;
    await _pump(
      tester,
      PendingMessageAttachments(
        attachments: [_file('holiday.jpg', 'image/jpeg')],
        foreground: Colors.black,
        muted: Colors.grey,
        uploading: true,
        progress: 0.4,
        onCancel: () => cancelled++,
      ),
    );

    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('holiday.jpg'), findsNothing);
    expect(find.byKey(const Key('pending-upload-preview')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);

    await tester.tap(find.byKey(PendingUploadRing.ringKey));
    await tester.pump();
    expect(cancelled, 1);
  });

  testWidgets('a document stays a file preview with the same control', (
    tester,
  ) async {
    await _pump(
      tester,
      PendingMessageAttachments(
        attachments: [_file('brief.pdf', 'application/pdf')],
        foreground: Colors.black,
        muted: Colors.grey,
        uploading: true,
        progress: 0.2,
        cancelLabel: 'Cancel',
        onCancel: () {},
      ),
    );

    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('brief.pdf'), findsOneWidget);
    expect(find.byKey(PendingUploadRing.ringKey), findsOneWidget);
  });

  testWidgets('a finished pending row has no cancel ring', (tester) async {
    await _pump(
      tester,
      PendingMessageAttachments(
        attachments: [_file('brief.pdf', 'application/pdf')],
        foreground: Colors.black,
        muted: Colors.grey,
        uploading: false,
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byIcon(Icons.close_rounded), findsNothing);
    expect(find.text('brief.pdf'), findsOneWidget);
  });
}
