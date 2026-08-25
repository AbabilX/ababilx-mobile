/// Identity of a chat tray entry and of the buttons on it.
///
/// One notification per conversation, not per message: MessagingStyle stacks
/// the messages inside a single entry the way Signal and the Google Messages
/// app do, and a reply has to land on a conversation, not on a line.
library;

/// Android notification ids are 32-bit; keep the derived id in range.
int chatNotificationId(String conversationId) =>
    conversationId.hashCode & 0x7fffffff;

/// Action ids come back on the notification response, so they are the contract
/// between the button and the handler.
const chatReplyActionId = 'chat_reply';
const chatMarkReadActionId = 'chat_mark_read';

/// Groups every chat entry under one bundle in the shade.
const chatNotificationGroupKey = 'com.ababilx.app.CHAT';
