import 'package:ababilx/features/messages/data/models/chat_models.dart';
import 'package:ababilx/features/messages/chat-timeline/save_message_attachments.dart';
import 'package:ababilx/shared/media/save_to_phone.dart';
import 'package:flutter_test/flutter_test.dart';

ChatMessageAttachment _attachment({
  String name = 'photo.jpg',
  String url = 'https://cdn.example/photo.jpg',
  bool locked = false,
}) => ChatMessageAttachment(
  id: name,
  messageId: 'm1',
  fileName: name,
  fileUrl: url,
  contentType: '',
  sizeBytes: 10,
  uploadedBy: 'u1',
  createdAt: '',
  locked: locked,
);

ChatMessage _message(List<ChatMessageAttachment> attachments) => ChatMessage(
  id: 'm1',
  conversationId: 'c1',
  userId: 'u1',
  body: '',
  createdAt: '',
  attachments: attachments,
);

void main() {
  group('media store collection', () {
    test('photos and video go where the gallery indexes them', () {
      expect(mediaStoreCollectionFor('image/jpeg'), 'images');
      expect(mediaStoreCollectionFor('video/mp4'), 'video');
    });

    test('everything else lands in Downloads', () {
      expect(mediaStoreCollectionFor('application/pdf'), 'downloads');
      expect(mediaStoreCollectionFor(''), 'downloads');
      expect(mediaStoreCollectionFor('audio/mp4'), 'downloads');
    });
  });

  group('save file names', () {
    test('strips separators MediaStore rejects', () {
      expect(safeSaveFileName('a/b\\c:d*e?f"g<h>i|j'), 'a_b_c_d_e_f_g_h_i_j');
    });

    test('an empty name falls back rather than writing nothing', () {
      expect(safeSaveFileName('   '), 'file');
      expect(safeSaveFileName('', fallback: 'blob-key'), 'blob-key');
    });

    test('an ordinary name is left alone', () {
      expect(
        safeSaveFileName('Q3 report (final).pdf'),
        'Q3 report (final).pdf',
      );
    });
  });

  group('saveable attachments', () {
    test('a locked file has no bytes anywhere, so it is not offered', () {
      final message = _message([_attachment(locked: true)]);
      expect(saveableAttachments(message), isEmpty);
      expect(canSaveMessageAttachments(message), isFalse);
    });

    test('a row with no URL is skipped', () {
      expect(saveableAttachments(_message([_attachment(url: '')])), isEmpty);
    });

    test('a message with no attachments never shows Save', () {
      expect(canSaveMessageAttachments(_message(const [])), isFalse);
    });

    test('locked files drop out but the rest still save', () {
      final message = _message([
        _attachment(name: 'a.jpg'),
        _attachment(name: 'b.jpg', locked: true),
        _attachment(name: 'c.pdf'),
      ]);
      expect(saveableAttachments(message).map((a) => a.fileName), [
        'a.jpg',
        'c.pdf',
      ]);
      expect(canSaveMessageAttachments(message), isTrue);
    });
  });
}
