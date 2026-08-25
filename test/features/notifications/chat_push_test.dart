import 'package:flutter_test/flutter_test.dart';

import 'package:ababilx/features/notifications/chat_push_decrypt.dart';
import 'package:ababilx/features/notifications/chat/chat_notification_ids.dart';
import 'package:ababilx/features/notifications/chat_push_notification.dart';

void main() {
  Map<String, dynamic> encryptedPush() => {
    'type': 'chat_dm',
    'conversation_id': 'c1',
    'message_id': 'm1',
    'sender_id': 's1',
    'recipient_id': 'r1',
    'enc_body': 'Y2lwaGVy',
    'enc_nonce': 'bm9uY2U=',
    'enc_key_version': '2',
  };

  test('encrypted DM pushes are recognised', () {
    expect(isEncryptedChatPush(encryptedPush()), isTrue);
  });

  test('a DM push without ciphertext is not decryptable', () {
    final data = encryptedPush()..remove('enc_body');
    expect(isEncryptedChatPush(data), isFalse);
  });

  test('channel pushes are never treated as encrypted', () {
    final data = encryptedPush()..['type'] = 'chat_message';
    expect(isEncryptedChatPush(data), isFalse);
  });

  test(
    'incomplete payloads decrypt to null without touching storage',
    () async {
      for (final missing in [
        'enc_body',
        'enc_nonce',
        'recipient_id',
        'sender_id',
        'conversation_id',
        'enc_key_version',
      ]) {
        final data = encryptedPush()..remove(missing);
        expect(
          await decryptChatPushBody(data),
          isNull,
          reason: 'missing $missing must fall back to the placeholder',
        );
      }
    },
  );

  test('notification id is per conversation and fits Android ids', () {
    final id = chatNotificationId('c1');
    expect(id, chatNotificationId('c1'));
    expect(id, greaterThanOrEqualTo(0));
    expect(id, lessThanOrEqualTo(0x7fffffff));
    expect(id, isNot(chatNotificationId('c2')));
  });

  test('every chat push type is rendered by the app itself', () {
    for (final type in ['chat_dm', 'chat_message', 'chat_mention']) {
      expect(isChatPush({'type': type}), isTrue, reason: type);
    }
    expect(isChatPush({'type': 'wall_mention'}), isFalse);
    expect(isChatPush(const {}), isFalse);
  });

  test('placeholder matches the server fallback copy', () {
    expect(encryptedPushPlaceholder, '🔒 Encrypted message');
  });
}
