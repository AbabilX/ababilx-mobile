import 'chat/chat_notification_presenter.dart';
import 'local_notifications.dart';

/// Chat pushes this app renders itself, as opposed to letting the system draw
/// the tray entry from the notification block.
const chatPushTypes = {'chat_dm', 'chat_message', 'chat_mention'};

bool isChatPush(Map<String, dynamic> data) =>
    chatPushTypes.contains(data['type']?.toString());

/// True when this push is an E2EE DM that arrived data-only, i.e. its text has
/// to be decrypted here before anything can be shown.
bool isEncryptedChatPush(Map<String, dynamic> data) =>
    data['type'] == 'chat_dm' &&
    (data['enc_body']?.toString().isNotEmpty ?? false);

/// Shows the tray entry for an encrypted DM: the placeholder first, rewritten
/// with the real text once this device has decrypted it.
Future<void> showEncryptedChatPush(
  LocalNotifications local,
  Map<String, dynamic> data,
) => ChatNotificationPresenter.show(local, data);

/// Shows a chat push whose text the server could send in the clear (channel
/// messages and mentions), in the same threaded entry an encrypted DM gets.
Future<void> showPlainChatPush(
  LocalNotifications local,
  Map<String, dynamic> data,
  String body,
) => ChatNotificationPresenter.show(local, data, plainBody: body);
