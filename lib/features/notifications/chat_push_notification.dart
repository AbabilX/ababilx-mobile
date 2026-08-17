import 'chat_push_decrypt.dart';
import 'local_notifications.dart';
import 'notification_router.dart';

/// True when this push is an E2EE DM that arrived data-only, i.e. its text has
/// to be decrypted here before anything can be shown.
bool isEncryptedChatPush(Map<String, dynamic> data) =>
    data['type'] == 'chat_dm' &&
    (data['enc_body']?.toString().isNotEmpty ?? false);

/// Shows the tray entry for an encrypted DM. The body only exists on this
/// device, so it is decrypted first and falls back to the placeholder when the
/// vault, the network or the payload cannot provide it.
Future<void> showEncryptedChatPush(
  LocalNotifications local,
  Map<String, dynamic> data,
) async {
  final body = await decryptChatPushBody(data) ?? encryptedPushPlaceholder;
  final title = data['title']?.toString() ?? 'AbabilX';
  await local.show(
    title: title,
    body: body,
    channelId: 'chat',
    payload: LocalNotifications.encodePayload(
      NotificationRouter.pathForData(data),
      data,
    ),
    // Same message → same tray entry, whichever isolate got there first.
    id: chatPushNotificationId(data),
  );
}

/// Android notification ids are 32-bit; keep the message-derived id in range.
int chatPushNotificationId(Map<String, dynamic> data) =>
    (data['message_id']?.toString() ?? '').hashCode & 0x7fffffff;
