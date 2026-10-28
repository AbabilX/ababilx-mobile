import 'package:ababilx/features/messages/data/local/android_chat_message_store.dart';
import 'package:ababilx/features/messages/data/local/chat_local_db.dart';
import 'package:ababilx/features/messages/data/local/chat_message_store.dart';
import 'package:ababilx/features/messages/data/local/drift_chat_message_store.dart';
import 'package:ababilx/features/messages/data/models/chat_message.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'an asynchronous native read failure returns the Drift history',
    () async {
      final db = ChatLocalDb.forTesting(NativeDatabase.memory());
      const channel = MethodChannel('com.ababilx.app/chat_store');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'isLegacyMigrated') return true;
        if (call.method == 'page')
          throw PlatformException(code: 'db_unavailable');
        return null;
      });
      try {
        await DriftChatMessageStore(db, keepPerConversation: 200000).saveAll([
          const ChatMessage(
            id: 'held',
            conversationId: 'c',
            userId: 'u',
            body: 'offline history',
            createdAt: '2026-10-01T00:00:00Z',
          ),
        ]);
        final store = ChatMessageStore(
          db,
          androidStore: const AndroidChatMessageStore(),
        );
        expect((await store.page('c')).map((m) => m.id), ['held']);
      } finally {
        messenger.setMockMethodCallHandler(channel, null);
        await db.close();
      }
    },
  );
}
