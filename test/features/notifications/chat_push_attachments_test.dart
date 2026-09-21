import 'package:ababilx/features/notifications/chat/chat_notification_store.dart';
import 'package:ababilx/features/notifications/chat/chat_push_attachments.dart';
import 'package:flutter_test/flutter_test.dart';

ChatPushAttachments? of(String kind, String count) =>
    ChatPushAttachments.of({'att_kind': kind, 'att_count': count});

void main() {
  test('labels match the server copy', () {
    expect(of('photo', '1')!.label, '📷 Photo');
    expect(of('photo', '3')!.label, '📷 3 photos');
    expect(of('video', '1')!.label, '🎥 Video');
    expect(of('voice', '1')!.label, '🎤 Voice message');
    expect(of('file', '2')!.label, '📎 2 files');
    expect(of('mixed', '2')!.label, '📎 2 attachments');
  });

  test('a caption keeps the icon, an empty one falls back to the label', () {
    expect(of('photo', '1')!.line('look'), '📷 look');
    expect(of('photo', '1')!.line('  '), '📷 Photo');
  });

  test('no attachment fields means no attachments', () {
    expect(ChatPushAttachments.of({}), isNull);
    expect(of('photo', '0'), isNull);
  });

  test('only a single photo is drawn in the tray', () {
    expect(of('photo', '1')!.isSinglePhoto, isTrue);
    expect(of('photo', '2')!.isSinglePhoto, isFalse);
    expect(of('video', '1')!.isSinglePhoto, isFalse);
  });

  test('the image URI survives the store round trip', () {
    final m = ChatNotificationMessage(
      messageId: 'm',
      sender: 'A',
      text: '📷 Photo',
      sentAt: DateTime(2026),
      imageUri: 'content://x/images/m.jpg',
    );
    final back = ChatNotificationMessage.fromJson(m.toJson());
    expect(back.imageUri, 'content://x/images/m.jpg');
    expect(back.copyWith(text: 'y').imageUri, 'content://x/images/m.jpg');
    expect(
      ChatNotificationMessage.fromJson({'id': 'n', 'text': 't'}).imageUri,
      isNull,
    );
  });
}
