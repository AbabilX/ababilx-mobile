import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ababilx/features/notifications/chat/chat_notification_builder.dart';
import 'package:ababilx/features/notifications/chat/chat_notification_ids.dart';

void main() {
  test('a top-level message is its own thread root', () {
    expect(chatThreadRootId({'message_id': 'm1'}), 'm1');
    expect(chatThreadRootId({'message_id': 'm1', 'parent_id': ''}), 'm1');
  });

  test('a thread reply joins the thread it is already in', () {
    expect(chatThreadRootId({'message_id': 'm2', 'parent_id': 'root'}), 'root');
  });

  test('no id means no root', () {
    expect(chatThreadRootId({'conversation_id': 'c1'}), '');
  });

  test('the chat entry offers Reply, Reply in thread and Mark read', () {
    final details = buildChatNotificationDetails(
      messages: const [],
      isGroup: false,
      alertOnce: true,
    );
    expect(details.actions!.map((a) => a.id), [
      chatReplyActionId,
      chatThreadReplyActionId,
      chatMarkReadActionId,
    ]);
    final thread = details.actions![1];
    expect(thread.inputs, isNotEmpty);
    expect(thread.cancelNotification, isTrue);
  });

  test('a hidden entry offers no reply of either kind', () {
    final List<AndroidNotificationAction> actions =
        buildHiddenChatNotificationDetails(alertOnce: true).actions!;
    expect(actions.map((a) => a.id), [chatMarkReadActionId]);
  });
}
