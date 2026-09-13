import 'package:ababilx/features/messages/chat-timeline/media-preview/chat_media_preview_caption.dart';
import 'package:ababilx/features/messages/chat-timeline/media-preview/chat_media_preview_meta.dart';
import 'package:ababilx/features/messages/chat-timeline/media-preview/chat_media_preview_rail.dart';
import 'package:ababilx/features/messages/data/models/chat_models.dart';
import 'package:ababilx/shared/widgets/image_preview_dock.dart';
import 'package:ababilx/shared/widgets/image_preview_top_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ChatMessage _message({
  required String userId,
  String? userName,
  String body = '',
  String createdAt = '2026-09-14T10:00:00Z',
  String messageType = 'text',
  Map<String, dynamic>? meta,
}) => ChatMessage(
  id: 'm1',
  conversationId: 'c1',
  userId: userId,
  userName: userName,
  body: body,
  createdAt: createdAt,
  messageType: messageType,
  meta: meta,
);

ChatMessageAttachment _photo(String id) => ChatMessageAttachment(
  id: id,
  messageId: 'm1',
  fileName: '$id.jpg',
  fileUrl: 'https://example.invalid/$id',
  contentType: 'image/jpeg',
  sizeBytes: 10,
  uploadedBy: 'u',
  createdAt: '',
);

void main() {
  test('own photo titles You and keeps the caption', () {
    final meta = ChatMediaPreviewMeta.of(
      message: _message(userId: 'me', userName: 'Murad', body: 'look at this'),
      isOwn: true,
      senderName: 'Murad',
    );
    expect(meta.title, 'You');
    expect(meta.detail, contains('You · '));
    expect(meta.caption, 'look at this');
    expect(meta.subtitle, isNotNull);
  });

  test('incoming photo uses the nickname, not You', () {
    final meta = ChatMediaPreviewMeta.of(
      message: _message(userId: 'them', userName: 'Alice', body: ''),
      isOwn: false,
      senderName: 'Ali',
    );
    expect(meta.title, 'Ali');
    expect(meta.caption, isNull);
  });

  test('webhook photo uses the feed name', () {
    final meta = ChatMediaPreviewMeta.of(
      message: _message(
        userId: '',
        messageType: 'webhook',
        meta: const {'source_name': 'GitHub'},
      ),
      isOwn: false,
      senderName: 'Unknown',
    );
    expect(meta.title, 'GitHub');
  });

  testWidgets('toolbar shows the file name, not Photo, and no overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ImagePreviewTopBar(
            fileName: 'holiday.jpg',
            detail: 'You · 10:00 AM',
          ),
        ),
      ),
    );
    expect(find.text('holiday.jpg'), findsOneWidget);
    expect(find.text('You · 10:00 AM'), findsOneWidget);
    expect(find.text('Photo'), findsNothing);
    expect(find.byIcon(Icons.more_vert_rounded), findsNothing);
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
  });

  testWidgets('capsule dock shows Save, Rotate and Share', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ImagePreviewDock(
            fileName: 'holiday.jpg',
            localPath: '/tmp/holiday.jpg',
            onRotate: () {},
          ),
        ),
      ),
    );
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Rotate'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    expect(find.byIcon(Icons.more_vert_rounded), findsNothing);
    expect(
      tester
          .widgetList<Material>(find.byType(Material))
          .any((m) => m.shape is StadiumBorder),
      isTrue,
    );
  });

  testWidgets('album rail stays away from a single photo', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ChatMediaPreviewRail(
          images: [_photo('a')],
          index: 0,
          onSelect: (_) {},
        ),
      ),
    );
    expect(find.byType(ListView), findsNothing);
  });

  testWidgets('caption expands on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ChatMediaPreviewCaption(
            text: 'one two three four five six seven eight',
          ),
        ),
      ),
    );
    await tester.tap(find.byType(ChatMediaPreviewCaption));
    await tester.pump();
    expect(
      find.text('one two three four five six seven eight'),
      findsOneWidget,
    );
  });
}
