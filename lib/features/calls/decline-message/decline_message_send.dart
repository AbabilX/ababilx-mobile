import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/localization/app_translations.dart';
import '../../../core/storage/secure_storage.dart';
import '../../notifications/chat/chat_notification_ids.dart';
import '../../notifications/chat/chat_notification_reply.dart';
import '../../notifications/local_notifications.dart';
import 'decline_replies.dart';

/// Sends the text a person declined a call with, into the call's DM.
///
/// The same sender a notification-shade reply uses, so it works from any
/// isolate — the CallKit background isolate of a killed app included — and
/// the DM is sealed on this phone exactly as the composer would seal it.
/// [myUserId] is who the vault seals as; without it the send is refused
/// rather than going out in plaintext to a conversation that never is.
Future<bool> sendCallDeclineMessage({
  required String conversationId,
  required String text,
  String? myUserId,
}) async {
  final body = text.trim();
  if (conversationId.isEmpty || body.isEmpty) return false;
  var me = myUserId ?? '';
  if (me.isEmpty) {
    try {
      const storage = SecureStorage(FlutterSecureStorage());
      me = await storage.readLocalDataOwnerUserId() ?? '';
    } catch (_) {}
  }
  if (me.isEmpty) return false;
  return sendChatNotificationReply({
    'conversation_id': conversationId,
    'recipient_id': me,
  }, body);
}

/// A native decline that carried a reply: send it, or do nothing.
///
/// Nobody is looking at a screen of ours when this runs (the ringing
/// Activity closed with the decline), so a failure becomes a notification
/// holding the text — the shade reply's rule: typed words never vanish.
Future<bool> sendCallDeclineMessageFromExtra(
  Map<String, dynamic>? extra, {
  String? myUserId,
}) async {
  final text = DeclineReplies.messageOf(extra);
  if (text == null) return false;
  final conversationId = extra?['conversation_id']?.toString() ?? '';
  final sent = await sendCallDeclineMessage(
    conversationId: conversationId,
    text: text,
    myUserId: myUserId,
  );
  if (!sent) await _reportUnsent(conversationId, text);
  return sent;
}

Future<void> _reportUnsent(String conversationId, String text) async {
  try {
    final lang = await DeclineReplies.language();
    final local = LocalNotifications();
    await local.initForBackground();
    await local.show(
      title: AppTranslations.of(lang, 'call_decline_message_failed'),
      body: text,
      channelId: 'chat',
      payload: LocalNotifications.encodePayload(
        conversationId.isEmpty ? '/messages' : '/messages/$conversationId',
      ),
      id: chatNotificationId('decline-failed-$conversationId'),
    );
  } catch (_) {
    // Nothing further to fall back to.
  }
}
