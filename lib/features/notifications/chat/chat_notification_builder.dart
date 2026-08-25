import 'dart:ui' show Color;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'chat_notification_ids.dart';
import 'chat_notification_store.dart';

/// The user, as the notification sees them. MessagingStyle needs a person for
/// "me" to tell an outgoing line from an incoming one.
const _me = Person(name: 'You', key: 'me');

/// Builds the Android tray entry for a conversation: a MessagingStyle thread
/// with the messages stacked under the sender's name, plus the reply and
/// mark-read buttons.
///
/// [alertOnce] is set when the post only rewrites an entry that is already up
/// (a placeholder becoming the decrypted text, or a sent reply being appended)
/// so the phone does not buzz twice for one message.
AndroidNotificationDetails buildChatNotificationDetails({
  required List<ChatNotificationMessage> messages,
  required bool isGroup,
  required bool alertOnce,
  String? conversationTitle,
}) => AndroidNotificationDetails(
  'chat',
  'Chat',
  channelDescription: 'Direct messages and mentions',
  importance: Importance.high,
  priority: Priority.high,
  category: AndroidNotificationCategory.message,
  icon: 'ic_stat_ababilx',
  color: const Color(0xFF6366F1),
  groupKey: chatNotificationGroupKey,
  onlyAlertOnce: alertOnce,
  styleInformation: MessagingStyleInformation(
    _me,
    conversationTitle: conversationTitle,
    groupConversation: isGroup,
    messages: [
      for (final message in messages)
        Message(
          message.text,
          message.sentAt,
          message.fromMe
              ? null
              : Person(name: message.sender, key: message.sender),
        ),
    ],
  ),
  actions: const [
    AndroidNotificationAction(
      chatReplyActionId,
      'Reply',
      // Direct reply: Android collects the text in the shade and hands it to
      // the background handler, which sends it without opening the app.
      inputs: [AndroidNotificationActionInput(label: 'Reply')],
      // The entry stays up and is rewritten with the sent reply appended.
      cancelNotification: false,
      allowGeneratedReplies: true,
      semanticAction: SemanticAction.reply,
    ),
    AndroidNotificationAction(
      chatMarkReadActionId,
      'Mark read',
      semanticAction: SemanticAction.markAsRead,
    ),
  ],
);

/// Who sent the message.
///
/// The push carries the sender on its own; a message from a server build that
/// predates that field only has it inside the title ("New message from Rahim").
String chatSenderName(Map<String, dynamic> data) {
  final name = data['sender_name']?.toString() ?? '';
  if (name.isNotEmpty) return name;
  final title = data['title']?.toString() ?? '';
  const prefix = 'New message from ';
  if (title.startsWith(prefix)) return title.substring(prefix.length);
  return title.isEmpty ? 'AbabilX' : title;
}

/// Title line for a conversation whose thread is not a 1:1 DM.
///
/// A DM has no conversation title on purpose: MessagingStyle then uses the
/// sender as the heading, which is what a phone user expects from a DM.
String? chatConversationTitle({
  required bool isGroup,
  required String pushTitle,
}) => isGroup && pushTitle.isNotEmpty ? pushTitle : null;
