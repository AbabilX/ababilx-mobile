import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:ababilx/features/notifications/chat/chat_notification_builder.dart';
import 'package:ababilx/features/notifications/chat/chat_notification_store.dart';

void main() {
  ChatNotificationMessage line(
    String id,
    String text, {
    String sender = 'Rahim',
    int minute = 0,
    bool fromMe = false,
  }) => ChatNotificationMessage(
    messageId: id,
    sender: sender,
    text: text,
    sentAt: DateTime(2026, 8, 25, 10, minute),
    fromMe: fromMe,
  );

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('messages stack in the order they arrived', () async {
    await ChatNotificationStore.upsert('c1', line('m1', 'first'));
    final messages = await ChatNotificationStore.upsert(
      'c1',
      line('m2', 'second', minute: 1),
    );

    expect(messages.map((m) => m.text), ['first', 'second']);
  });

  test('the same message id rewrites its line instead of stacking', () async {
    await ChatNotificationStore.upsert(
      'c1',
      line('m1', '🔒 Encrypted message'),
    );
    final messages = await ChatNotificationStore.upsert(
      'c1',
      line('m1', 'the real text'),
    );

    expect(messages, hasLength(1));
    expect(messages.single.text, 'the real text');
  });

  test('reports whether an update is a new message or a redelivery', () async {
    final first = await ChatNotificationStore.upsertDetailed(
      'c1',
      line('m1', 'first'),
    );
    final duplicate = await ChatNotificationStore.upsertDetailed(
      'c1',
      line('m1', 'first again'),
    );

    expect(first.inserted, isTrue);
    expect(duplicate.inserted, isFalse);
    expect(duplicate.messages, hasLength(1));
  });

  test('an old thread is trimmed to what the shade can show', () async {
    var messages = <ChatNotificationMessage>[];
    for (var i = 0; i < 12; i++) {
      messages = await ChatNotificationStore.upsert(
        'c1',
        line('m$i', 'line $i', minute: i),
      );
    }

    expect(messages, hasLength(8));
    expect(messages.first.text, 'line 4');
    expect(messages.last.text, 'line 11');
  });

  test('conversations do not share a thread', () async {
    await ChatNotificationStore.upsert('c1', line('m1', 'in c1'));
    await ChatNotificationStore.upsert('c2', line('m2', 'in c2'));

    expect((await ChatNotificationStore.read('c1')).single.text, 'in c1');
    expect((await ChatNotificationStore.read('c2')).single.text, 'in c2');
  });

  test('clearing a conversation empties its thread', () async {
    await ChatNotificationStore.upsert('c1', line('m1', 'in c1'));
    await ChatNotificationStore.clear('c1');

    expect(await ChatNotificationStore.read('c1'), isEmpty);
  });

  test('a reply the user sent is kept as their own line', () async {
    final messages = await ChatNotificationStore.upsert(
      'c1',
      line('r1', 'on my way', sender: 'You', fromMe: true),
    );

    expect(messages.single.fromMe, isTrue);
  });

  group('sender name', () {
    test('comes from the push field when the server sends it', () {
      expect(chatSenderName({'sender_name': 'Rahim'}), 'Rahim');
    });

    test('falls back to the DM title of an older server build', () {
      expect(chatSenderName({'title': 'New message from Rahim'}), 'Rahim');
    });

    test('never ends up empty', () {
      expect(chatSenderName(const {}), 'AbabilX');
    });
  });

  group('conversation title', () {
    test('a DM has none, so the sender heads the thread', () {
      expect(
        chatConversationTitle(isGroup: false, pushTitle: 'New message from X'),
        isNull,
      );
    });

    test('a channel keeps the push title as the heading', () {
      expect(
        chatConversationTitle(isGroup: true, pushTitle: 'Rahim in #dev'),
        'Rahim in #dev',
      );
    });
  });

  test('inline reply consumes the native notification immediately', () {
    final details = buildChatNotificationDetails(
      messages: [line('m1', 'hello')],
      isGroup: false,
      alertOnce: false,
    );

    expect(details.actions?.first.cancelNotification, isTrue);
  });
}
