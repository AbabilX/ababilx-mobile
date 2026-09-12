import 'package:ababilx/features/messages/data/local/android_chat_message_store.dart';
import 'package:ababilx/features/messages/data/local/chat_local_db.dart';
import 'package:ababilx/features/messages/data/local/chat_message_store.dart';
import 'package:ababilx/features/messages/data/models/chat_message.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('com.ababilx.app/chat_store');

ChatMessage _message() => const ChatMessage(
  id: 'message-1',
  conversationId: 'conversation-1',
  userId: 'user-1',
  body: 'private',
  createdAt: '2026-09-12T00:00:00Z',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ChatLocalDb db;
  late List<String> calls;

  setUp(() {
    db = ChatLocalDb.forTesting(NativeDatabase.memory());
    calls = [];
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
    await db.close();
  });

  test('account wipe clears Android SQLCipher and Drift stores', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          calls.add(call.method);
          return null;
        });
    final store = ChatMessageStore(
      db,
      androidStore: const AndroidChatMessageStore(),
    );
    await store.saveAll([_message()]);

    await store.clearAll();

    expect(calls, contains('clearAll'));
    expect(await ChatMessageStore(db).page('conversation-1'), isEmpty);
  });

  test('native wipe failure aborts before Drift is cleared', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          if (call.method == 'clearAll') throw PlatformException(code: 'disk');
          return null;
        });
    final store = ChatMessageStore(
      db,
      androidStore: const AndroidChatMessageStore(),
    );
    await store.saveAll([_message()]);

    await expectLater(store.clearAll(), throwsA(isA<PlatformException>()));

    expect(await ChatMessageStore(db).page('conversation-1'), hasLength(1));
  });
}
