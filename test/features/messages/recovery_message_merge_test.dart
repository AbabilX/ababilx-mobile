import 'package:ababilx/features/messages/data/local/chat_local_db.dart';
import 'package:ababilx/features/messages/data/local/chat_message_store.dart';
import 'package:ababilx/features/messages/data/models/chat_message.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

ChatMessage message(
  String body,
  int revision, {
  bool purged = false,
  bool deleted = false,
}) => ChatMessage(
  id: 'm',
  conversationId: 'c',
  userId: 'u',
  body: body,
  createdAt: '2026-01-01T00:00:00Z',
  revision: revision,
  contentPurged: purged,
  deletedAt: deleted ? '2026-09-10T00:00:00Z' : null,
);
void main() {
  late ChatLocalDb db;
  late ChatMessageStore store;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = ChatLocalDb.forTesting(NativeDatabase.memory());
    store = ChatMessageStore(db);
  });
  tearDown(() => db.close());
  test('old archive cannot replace a newer device message', () async {
    await store.saveAll([message('edited', 12)]);
    await store.saveRecovered([message('old', 4)], fromBackup: true);
    expect((await store.page('c')).single.body, 'edited');
  });
  test('server expiry preserves downloaded device history', () async {
    await store.saveAll([message('keep me', 4)]);
    await store.saveRecovered([
      message('', 15, purged: true),
    ], fromBackup: false);
    expect((await store.page('c')).single.body, 'keep me');
  });
  test('unknown archive revision does not override the live copy', () async {
    await store.saveAll([message('live legacy', 0)]);
    await store.saveRecovered([message('backup', 22)], fromBackup: true);
    expect((await store.page('c')).single.body, 'live legacy');
    await store.saveRecovered([
      message('current server', 23),
    ], fromBackup: false);
    expect((await store.page('c')).single.body, 'current server');
  });
  test(
    'a deleted local message is not resurrected by an old archive',
    () async {
      await store.deletions.load('u');
      await store.deletions.rememberMessage('c', 'm');
      await store.saveRecovered([message('old', 0)], fromBackup: true);
      expect(await store.page('c'), isEmpty);
    },
  );
}
