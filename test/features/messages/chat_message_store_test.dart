import 'package:ababilx/features/messages/data/local/chat_local_db.dart';
import 'package:ababilx/features/messages/data/local/chat_message_store.dart';
import 'package:ababilx/features/messages/data/models/chat_message.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

ChatMessage msg(
  String id,
  String createdAt, {
  String body = 'hello',
  String conversationId = 'c1',
  String? encryptedBody,
}) => ChatMessage(
  id: id,
  conversationId: conversationId,
  userId: 'u1',
  body: body,
  createdAt: createdAt,
  encryptedBody: encryptedBody,
  encryptionVersion: encryptedBody == null ? null : 1,
);

void main() {
  late ChatLocalDb db;
  late ChatMessageStore store;

  setUp(() {
    db = ChatLocalDb.forTesting(NativeDatabase.memory());
    store = ChatMessageStore(db);
  });

  tearDown(() => db.close());

  test('pages oldest-first and walks backwards through history', () async {
    await store.saveAll([
      for (var i = 1; i <= 5; i++)
        msg('m$i', '2026-08-2${i}T00:00:00Z', body: 'body $i'),
    ]);

    final newest = await store.page('c1', limit: 2);
    expect(newest.map((m) => m.id), ['m4', 'm5']);

    final older = await store.page('c1', limit: 2, beforeMs: _ms(newest.first));
    // The bound is inclusive, so the edge message comes back with the page.
    expect(older.map((m) => m.id), ['m3', 'm4']);
    expect(await store.hasOlderThan('c1', _ms(older.first)), isTrue);
  });

  test('offline search matches body, never an encrypted message', () async {
    await store.saveAll([
      msg('m1', '2026-08-21T00:00:00Z', body: 'deploy the server'),
      msg('m2', '2026-08-22T00:00:00Z', body: 'lunch plans'),
      msg(
        'm3',
        '2026-08-23T00:00:00Z',
        body: 'deploy secret',
        encryptedBody: 'Y2lwaGVy',
      ),
    ]);

    final hits = await store.search('deploy');
    expect(hits.map((m) => m.id), ['m1']);
  });

  test('downloaded encrypted chat can be found after memory decrypt', () async {
    await store.saveAll([
      msg(
        'm1',
        '2026-08-23T00:00:00Z',
        body: 'deploy secret',
        encryptedBody: 'Y2lwaGVy',
      ),
    ]);

    final hits = await LocalMessageSearch(store, (messages) async {
      return messages
          .map((message) => message.copyWith(body: 'deploy secret'))
          .toList();
    }).search('deploy');
    expect(hits.map((m) => m.id), ['m1']);
  });

  test('encrypted message is stored ciphertext-only', () async {
    await store.saveAll([
      msg(
        'm1',
        '2026-08-21T00:00:00Z',
        body: 'plaintext that must not persist',
        encryptedBody: 'Y2lwaGVy',
      ),
    ]);

    final stored = (await store.page('c1')).single;
    expect(stored.body, isEmpty);
    expect(stored.encryptedBody, 'Y2lwaGVy');
  });

  test('pending sends never reach the history table', () async {
    await store.saveAll([
      ChatMessage(
        id: 'p1',
        conversationId: 'c1',
        userId: 'u1',
        body: 'in flight',
        createdAt: '2026-08-21T00:00:00Z',
        sendStatus: MessageSendStatus.sending,
      ),
    ]);

    expect(await store.page('c1'), isEmpty);
  });

  test('prunes a conversation back to its retention window', () async {
    final small = ChatMessageStore(db, keepPerConversation: 3);
    await small.saveAll([
      for (var i = 1; i <= 5; i++) msg('m$i', '2026-08-2${i}T00:00:00Z'),
    ]);

    final kept = await small.page('c1', limit: 50);
    expect(kept.map((m) => m.id), ['m3', 'm4', 'm5']);
  });

  test('deletes and clears only what it is asked to', () async {
    await store.saveAll([
      msg('m1', '2026-08-21T00:00:00Z'),
      msg('o1', '2026-08-21T00:00:00Z', conversationId: 'c2'),
    ]);

    await store.remove('m1');
    expect(await store.page('c1'), isEmpty);
    expect((await store.page('c2')).single.id, 'o1');

    await store.clearAll();
    expect(await store.page('c2'), isEmpty);
  });
}

int _ms(ChatMessage m) => DateTime.parse(m.createdAt).millisecondsSinceEpoch;
