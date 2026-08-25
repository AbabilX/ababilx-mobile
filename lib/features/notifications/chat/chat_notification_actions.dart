import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../fcm_log.dart';
import '../local_notifications.dart';
import 'chat_notification_ids.dart';
import 'chat_notification_presenter.dart';
import 'chat_notification_reply.dart';

/// Entry point Android calls when a notification button is used while the app
/// is not in the foreground. Must stay top-level and annotated, or the compiler
/// strips it out of the release build.
@pragma('vm:entry-point')
void chatNotificationBackgroundAction(NotificationResponse response) {
  // Fresh isolate: nothing is registered until asked for.
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  handleChatNotificationAction(response);
}

/// Runs a chat notification button. Shared by both isolates: the same reply has
/// to work whether the app is running or long dead.
///
/// Returns true when the response was a chat action and was handled, so a
/// caller that also does tap navigation knows to stop.
Future<bool> handleChatNotificationAction(NotificationResponse response) async {
  final actionId = response.actionId;
  if (actionId != chatReplyActionId && actionId != chatMarkReadActionId) {
    return false;
  }

  final data = LocalNotifications.decodeData(response.payload ?? '');
  final conversationId = data['conversation_id']?.toString() ?? '';
  // Same instance the app already uses when this runs in the main isolate; a
  // fresh, uninitialised one in the action isolate.
  final local = LocalNotifications();
  await local.initForBackground();

  if (actionId == chatMarkReadActionId) {
    final ok = await markChatNotificationRead(conversationId);
    fcmLog('notif.action.mark_read', 'conversation=$conversationId ok=$ok');
    await ChatNotificationPresenter.dismiss(local, conversationId);
    return true;
  }

  final text = response.input?.trim() ?? '';
  if (text.isEmpty) return true;
  // Show the reply in the thread first: the send needs the network, and the
  // shade should never look like the typing was thrown away.
  await ChatNotificationPresenter.appendOutgoing(local, data, text);

  final sent = await sendChatNotificationReply(data, text);
  fcmLog('notif.action.reply', 'conversation=$conversationId sent=$sent');
  if (!sent) await _reportFailedReply(local, conversationId, text);
  return true;
}

/// A reply that never reached the server must not disappear silently — the
/// text goes back to the user so it can be sent again from the app.
Future<void> _reportFailedReply(
  LocalNotifications local,
  String conversationId,
  String text,
) async {
  await ChatNotificationPresenter.dismiss(local, conversationId);
  await local.show(
    title: 'Reply not sent',
    body: text,
    channelId: 'chat',
    payload: LocalNotifications.encodePayload(
      conversationId.isEmpty ? '/messages' : '/messages/$conversationId',
    ),
    id: chatNotificationId('failed-$conversationId'),
  );
}
