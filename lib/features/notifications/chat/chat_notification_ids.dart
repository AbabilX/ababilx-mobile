/// Identity of a chat tray entry and of the buttons on it.
///
/// One notification per conversation, not per message: MessagingStyle stacks
/// the messages inside a single entry the way the reference app and the Google
/// Messages app do, and a reply has to land on a conversation, not on a line.
library;

/// Android notification ids are 32-bit; keep the derived id in range.
int chatNotificationId(String conversationId) =>
    conversationId.hashCode & 0x7fffffff;

/// Tag of the entry Android itself draws for a plaintext chat push (webhook
/// feeds). FCM posts it as (tag, id 0). MUST match `notify.ChatPushTag` in
/// ababilx-server and `chatPushTag` in ababilx-notification.
String chatSystemNotificationTag(String conversationId) =>
    'chat_$conversationId';

/// Action ids come back on the notification response, so they are the contract
/// between the button and the handler.
const chatReplyActionId = 'chat_reply';
const chatThreadReplyActionId = 'chat_reply_thread';
const chatMarkReadActionId = 'chat_mark_read';

/// Groups every chat entry under one bundle in the shade.
const chatNotificationGroupKey = 'com.ababilx.app.CHAT';

/// The message a "Reply in thread" from the shade hangs under: the thread the
/// notified message is already in (`parent_id`, server-sent for a thread
/// reply), otherwise that message itself. Empty when the push names neither.
String chatThreadRootId(Map<String, dynamic> data) {
  final parent = data['parent_id']?.toString().trim() ?? '';
  if (parent.isNotEmpty) return parent;
  return data['message_id']?.toString().trim() ?? '';
}
