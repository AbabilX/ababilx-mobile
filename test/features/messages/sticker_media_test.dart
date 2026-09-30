import 'package:flutter_test/flutter_test.dart';

import 'package:ababilx/features/messages/chat-timeline/sticker_media.dart';
import 'package:ababilx/features/messages/data/models/chat_models.dart';

ChatMessageAttachment _file(String name, String type, {int? viewSeconds}) =>
    ChatMessageAttachment(
      id: name,
      messageId: 'm1',
      fileName: name,
      fileUrl: 'https://example.test/$name',
      contentType: type,
      sizeBytes: 10,
      uploadedBy: 'alice',
      createdAt: '2026-09-30T10:00:00Z',
      viewSeconds: viewSeconds,
    );

void main() {
  test('keyboard stickers and GIFs draw with no fill', () {
    expect(isStickerLike(_file('sticker-1.webp', 'image/webp')), isTrue);
    expect(isStickerLike(_file('sticker-1.png', 'image/png')), isTrue);
    expect(isStickerLike(_file('funny.gif', 'image/gif')), isTrue);
    // A missing type falls back to the name.
    expect(isStickerLike(_file('funny.gif', '')), isTrue);
  });

  test('ordinary photos keep their fill', () {
    expect(isStickerLike(_file('IMG_1.jpg', 'image/jpeg')), isFalse);
    expect(isStickerLike(_file('clip.mp4', 'video/mp4')), isFalse);
    expect(isStickerLike(_file('notes.pdf', 'application/pdf')), isFalse);
  });

  test('a timed sticker is a label card, not a sticker', () {
    final timed = _file('sticker-1.webp', 'image/webp', viewSeconds: 0);
    expect(isStickerLike(timed), isTrue);
    expect(
      isStickerMessage(
        ChatMessage(
          id: 'm1',
          conversationId: 'c1',
          userId: 'alice',
          body: '',
          attachments: [timed],
          createdAt: '2026-09-30T10:00:00Z',
        ),
      ),
      isFalse,
    );
  });
}
