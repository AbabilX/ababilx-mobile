import '../chat_push_decrypt.dart';
import '../local_notifications.dart';
import '../notification_router.dart';
import 'chat_notification_builder.dart';
import 'chat_notification_ids.dart';
import 'chat_notification_store.dart';
import 'chat_push_attachments.dart';
import 'chat_push_image.dart';

/// Raises and updates the tray entry for a chat push.
///
/// An encrypted DM arrives as ciphertext only, so the entry is posted first
/// with the placeholder and rewritten once the text is decrypted. Posting
/// first is deliberate: decrypting needs the vault and often the network, and
/// a notification that waits for that is a notification the user may never
/// see if the background isolate is killed first.
class ChatNotificationPresenter {
  const ChatNotificationPresenter._();

  static Future<void> show(
    LocalNotifications local,
    Map<String, dynamic> data, {
    String? plainBody,
  }) async {
    final conversationId = data['conversation_id']?.toString() ?? '';
    final messageId = data['message_id']?.toString() ?? '';
    if (conversationId.isEmpty || messageId.isEmpty) {
      // Nothing to thread this into — show it flat rather than not at all.
      await local.show(
        title: data['title']?.toString() ?? 'AbabilX',
        body: plainBody ?? encryptedPushPlaceholder,
        channelId: 'chat',
        payload: _payload(data),
      );
      return;
    }

    final attachments = ChatPushAttachments.of(data);
    final encrypted = plainBody == null;
    // An attachment names itself before anything is decrypted: "📷 Photo"
    // tells the reader more than the lock placeholder does.
    var text = plainBody ?? attachments?.label ?? encryptedPushPlaceholder;
    await _post(local, data, text: text, alertOnce: false);

    if (encrypted) {
      final decrypted = await decryptChatPushBody(data);
      if (decrypted != null && decrypted.isNotEmpty) {
        text = attachments?.line(decrypted) ?? decrypted;
        // Same message id, so this rewrites the line in place instead of
        // stacking a second copy of the message.
        await _post(local, data, text: text, alertOnce: true);
      }
    }

    if (attachments?.isSinglePhoto ?? false) {
      final image = await fetchChatPushImage(
        conversationId: conversationId,
        messageId: messageId,
      );
      if (image != null) {
        await _post(local, data, text: text, alertOnce: true, imageUri: image);
      }
    }
  }

  /// Appends a reply the user just sent from the notification, so the thread in
  /// the shade reads like the conversation does in the app.
  static Future<void> appendOutgoing(
    LocalNotifications local,
    Map<String, dynamic> data,
    String text,
  ) => _post(
    local,
    data,
    text: text,
    alertOnce: true,
    messageId: 'reply-${DateTime.now().microsecondsSinceEpoch}',
    fromMe: true,
  );

  /// Drops a conversation's entry and its stored thread — the user has read it
  /// somewhere else.
  static Future<void> dismiss(
    LocalNotifications local,
    String conversationId,
  ) async {
    if (conversationId.isEmpty) return;
    await ChatNotificationStore.clear(conversationId);
    await local.cancel(chatNotificationId(conversationId));
  }

  static Future<void> _post(
    LocalNotifications local,
    Map<String, dynamic> data, {
    required String text,
    required bool alertOnce,
    String? messageId,
    bool fromMe = false,
    String? imageUri,
  }) async {
    final conversationId = data['conversation_id']?.toString() ?? '';
    final title = data['title']?.toString() ?? 'AbabilX';
    // MessagingStyle wants to know whether to name the sender on each line.
    // Type is the right test here — this is about shape, not encryption.
    final isGroup = data['type']?.toString() != 'chat_dm';
    final upsert = await ChatNotificationStore.upsertDetailed(
      conversationId,
      ChatNotificationMessage(
        messageId: messageId ?? data['message_id']?.toString() ?? '',
        sender: chatSenderName(data),
        text: text,
        sentAt: DateTime.now(),
        fromMe: fromMe,
        imageUri: imageUri,
      ),
    );

    await local.showDetails(
      id: chatNotificationId(conversationId),
      title: title,
      body: text,
      payload: _payload(data),
      android: buildChatNotificationDetails(
        messages: upsert.messages,
        isGroup: isGroup,
        // JetStream/FCM is at-least-once. A repeated message ID rewrites the
        // existing line, but must not vibrate or sound again.
        alertOnce: alertOnce || !upsert.inserted,
        conversationTitle: chatConversationTitle(
          isGroup: isGroup,
          pushTitle: title,
        ),
      ),
    );
  }

  static String _payload(Map<String, dynamic> data) =>
      LocalNotifications.encodePayload(
        NotificationRouter.pathForData(data),
        data,
      );
}
