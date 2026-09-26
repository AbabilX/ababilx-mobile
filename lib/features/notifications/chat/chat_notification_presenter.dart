import '../chat_push_decrypt.dart';
import '../local_notifications.dart';
import '../notification_router.dart';
import 'chat_notification_builder.dart';
import 'chat_notification_dismissals.dart';
import 'chat_notification_hidden.dart';
import 'chat_notification_ids.dart';
import 'chat_notification_privacy.dart';
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
    // A locked chat, or one set to hide its notifications: name, text and
    // picture never reach the tray, and nothing is decrypted for it.
    if (await ChatNotificationPrivacy.isHidden(conversationId)) {
      await postHiddenChatNotification(local, data);
      return;
    }
    // Private chat (server 0160): the push carries no content, and the entry
    // offers no reply from the shade.
    if (data['private_chat']?.toString() == '1') {
      await postHiddenChatNotification(local, data, private: true);
      return;
    }
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

    // Every post below waits on this: reading the chat in the app while the
    // decrypt or the photo is still in flight must not bring the entry back.
    final startedAt = DateTime.now();
    Future<bool> post(String text, {bool alertOnce = true, String? image}) =>
        _postUnlessRead(
          local,
          data,
          startedAt,
          text: text,
          alertOnce: alertOnce,
          imageUri: image,
        );

    final attachments = ChatPushAttachments.of(data);
    final encrypted = plainBody == null;
    // An attachment names itself before anything is decrypted: "📷 Photo"
    // tells the reader more than the lock placeholder does.
    var text = plainBody ?? attachments?.label ?? encryptedPushPlaceholder;
    if (!await post(text, alertOnce: false)) return;

    if (encrypted) {
      final decrypted = await decryptChatPushBody(data);
      if (decrypted != null && decrypted.isNotEmpty) {
        text = attachments?.line(decrypted) ?? decrypted;
        // Same message id, so this rewrites the line in place instead of
        // stacking a second copy of the message.
        if (!await post(text)) return;
      }
    }

    if (attachments?.isSinglePhoto ?? false) {
      final image = await fetchChatPushImage(
        conversationId: conversationId,
        messageId: messageId,
      );
      if (image != null) await post(text, image: image);
    }
  }

  /// Posts unless the conversation was read since [startedAt], and takes the
  /// entry down again if the read landed while it was being posted. False
  /// means the reader has it, and nothing more should be drawn.
  static Future<bool> _postUnlessRead(
    LocalNotifications local,
    Map<String, dynamic> data,
    DateTime startedAt, {
    required String text,
    required bool alertOnce,
    String? imageUri,
  }) async {
    final conversationId = data['conversation_id']?.toString() ?? '';
    if (await ChatNotificationDismissals.readSince(conversationId, startedAt)) {
      return false;
    }
    await _post(
      local,
      data,
      text: text,
      alertOnce: alertOnce,
      imageUri: imageUri,
    );
    if (await ChatNotificationDismissals.readSince(conversationId, startedAt)) {
      await ChatNotificationStore.clear(conversationId);
      await local.cancel(chatNotificationId(conversationId));
      return false;
    }
    return true;
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
    // Marked first, so a background isolate mid-post sees it and stops.
    await ChatNotificationDismissals.mark(conversationId);
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
