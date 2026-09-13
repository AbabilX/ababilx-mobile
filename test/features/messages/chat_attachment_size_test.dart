import 'package:ababilx/features/messages/chat-timeline/composer_upload_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('chat attachments accept exactly 350 MiB', () {
    expect(
      () => validateChatAttachmentSize(350 * 1024 * 1024),
      returnsNormally,
    );
  });

  test('chat attachments reject bytes above 350 MiB', () {
    expect(
      () => validateChatAttachmentSize(350 * 1024 * 1024 + 1),
      throwsA(isA<ChatAttachmentSizeException>()),
    );
  });

  test('chat attachments reject empty files', () {
    expect(
      () => validateChatAttachmentSize(0),
      throwsA(isA<ChatAttachmentSizeException>()),
    );
  });
}
