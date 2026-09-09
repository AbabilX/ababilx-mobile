import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ababilx/features/messages/data/local/chat_local_db.dart';
import 'package:ababilx/features/messages/data/local/chat_message_store.dart';
import 'package:ababilx/features/messages/data/models/chat_message.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'missed deletion hides cached history and rejects stale backup writes',
    () async {
      SharedPreferences.setMockInitialValues({});
      final db = ChatLocalDb.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final store = ChatMessageStore(db);
      await store.deletions.load('user');
      ChatMessage message(String id, String at) => ChatMessage.fromJson({
        'id': id,
        'conversation_id': 'chat',
        'user_id': 'user',
        'body': 'saved content',
        'created_at': at,
      });
      final old = message('old', '2026-09-08T00:00:00Z');
      final recent = message('recent', '2026-09-10T00:00:00Z');
      await store.saveAll([old, recent]);
      expect((await store.page('chat')).length, 2);
      await store.deletions.replace([
        {
          'conversation_id': 'chat',
          'message_id': '',
          'through_at': '2026-09-09T00:00:00Z',
          'deleted_at': '2026-09-09T00:00:00Z',
          'entire_conversation': false,
        },
      ]);
      expect((await store.page('chat')).map((m) => m.id), ['recent']);
      await store.remove('old');
      await store.saveAll([old]); // A late response or archive import.
      expect((await store.exportPage()).map((m) => m.id), ['recent']);
      final restarted = ChatMessageStore(db);
      await restarted.deletions.load('user');
      await restarted.saveAll([old]);
      expect((await restarted.exportPage()).map((m) => m.id), ['recent']);
    },
  );
}
