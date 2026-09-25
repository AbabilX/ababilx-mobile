import '../local_notifications.dart';
import '../notification_router.dart';
import 'chat_notification_builder.dart';
import 'chat_notification_dismissals.dart';
import 'chat_notification_ids.dart';
import 'chat_notification_store.dart';

/// Posts "AbabilX · New message" for a chat that hides its notifications
/// (see `ChatNotificationPrivacy`). Nothing is decrypted, no photo fetched,
/// and the stored thread holds empty lines only — the count is all it keeps,
/// so no message text reaches the notification store on disk either.
///
/// The payload keeps only what a tap and Mark read need: the ciphertext and
/// the sender's name stay out of the PendingIntent too.
Future<void> postHiddenChatNotification(
  LocalNotifications local,
  Map<String, dynamic> data,
) async {
  final conversationId = data['conversation_id']?.toString() ?? '';
  final messageId = data['message_id']?.toString() ?? '';
  final now = DateTime.now();
  final bare = <String, dynamic>{
    'type': data['type']?.toString() ?? 'chat_dm',
    'conversation_id': conversationId,
    'message_id': messageId,
  };
  final upsert = await ChatNotificationStore.upsertDetailed(
    conversationId,
    ChatNotificationMessage(
      messageId: messageId.isEmpty
          ? 'hidden-${now.microsecondsSinceEpoch}'
          : messageId,
      sender: '',
      text: '',
      sentAt: now,
      fromMe: false,
    ),
  );
  if (await ChatNotificationDismissals.readSince(conversationId, now)) return;
  final count = upsert.messages.where((m) => !m.fromMe).length;
  await local.showDetails(
    id: chatNotificationId(conversationId),
    title: 'AbabilX',
    body: count > 1 ? '$count new messages' : 'New message',
    payload: LocalNotifications.encodePayload(
      NotificationRouter.pathForData(bare),
      bare,
    ),
    android: buildHiddenChatNotificationDetails(alertOnce: !upsert.inserted),
  );
}
