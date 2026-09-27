import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'chat_notification_ids.dart';

/// Removes the entry Android drew ITSELF for a plaintext chat push — a webhook
/// feed's message arrives with a notification block, so the OS posts it while
/// the app is backgrounded and the app's own id never reaches it. The server
/// tags it per conversation and FCM posts it as (tag, id 0).
///
/// Cancelling needs no plugin initialisation, so this works from any isolate.
Future<void> cancelChatSystemEntry(String conversationId) async {
  if (conversationId.isEmpty) return;
  if (defaultTargetPlatform != TargetPlatform.android) return;
  try {
    await FlutterLocalNotificationsPlugin().cancel(
      id: 0,
      tag: chatSystemNotificationTag(conversationId),
    );
  } catch (_) {
    // Already gone is fine.
  }
}
