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
  String? parentId,
}) => ChatMessage(
  id: id,
  conversationId: conversationId,
  userId: 'u1',
  body: body,
  createdAt: createdAt,
  encryptedBody: encryptedBody,
  encryptionVersion: encryptedBody == null ? null : 1,
  parentId: parentId,
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

    final older = await store.page(
      'c1',
      limit: 2,
      beforeMs: _ms(newest.first),
      beforeId: newest.first.id,
    );
    expect(older.map((m) => m.id), ['m2', 'm3']);
    expect(
      await store.hasOlderThan(
        'c1',
        _ms(older.first),
        beforeId: older.first.id,
      ),
      isTrue,
    );
  });

  test(
    'main timeline excludes replies and thread page contains only replies',
    () async {
      await store.saveAll([
        msg('root', '2026-08-21T00:00:00Z'),
        msg('reply', '2026-08-21T00:01:00Z', parentId: 'root'),
      ]);

      expect((await store.page('c1')).map((message) => message.id), ['root']);
      expect(
        (await store.page(
          'c1',
          threadRootId: 'root',
        )).map((message) => message.id),
        ['reply'],
      );
    },
  );

  test('equal timestamps use id as a deterministic secondary order', () async {
    await store.saveAll([
      msg('m4', '2026-08-21T00:00:00Z'),
      msg('m3', '2026-08-21T00:00:00Z'),
      msg('m2', '2026-08-21T00:00:00Z'),
      msg('m1', '2026-08-21T00:00:00Z'),
    ]);

    final newest = await store.page('c1', limit: 2);
    expect(newest.map((message) => message.id), ['m3', 'm4']);
    final older = await store.page(
      'c1',
      limit: 2,
      beforeMs: _ms(newest.first),
      beforeId: newest.first.id,
    );
    expect(older.map((message) => message.id), ['m1', 'm2']);
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

  test('a chat\'s own search only reads that chat, sealed rows too', () async {
    await store.saveAll([
      msg('m1', '2026-08-21T00:00:00Z', body: 'deploy here'),
      msg(
        'm2',
        '2026-08-22T00:00:00Z',
        body: 'deploy there',
        conversationId: 'c2',
      ),
      msg('m3', '2026-08-23T00:00:00Z', body: 'x', encryptedBody: 'Y2lwaGVy'),
      msg(
        'm4',
        '2026-08-24T00:00:00Z',
        body: 'x',
        encryptedBody: 'Y2lwaGVy',
        conversationId: 'c2',
      ),
    ]);

    final hits = await LocalMessageSearch(store, (messages) async {
      return messages
          .map((message) => message.copyWith(body: 'deploy sealed'))
          .toList();
    }).search('deploy', conversationId: 'c1');
    expect(hits.map((m) => m.id), ['m3', 'm1']);
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

  test(
    'an outgoing send is stored under its client ref and confirm updates that row',
    () async {
      const ref = 'client-1';
      await store.saveAll([
        ChatMessage(
          id: ref,
          conversationId: 'c1',
          userId: 'u1',
          body: 'in flight',
          createdAt: '2026-08-21T00:00:00Z',
          sendStatus: MessageSendStatus.sending,
          clientRef: ref,
        ),
      ]);

      final pending = (await store.page('c1')).single;
      expect(pending.sendStatus, MessageSendStatus.sending);
      expect(pending.id, ref);
      expect((await store.listUnsent()).single.id, ref);

      await store.saveAll([
        ChatMessage(
          id: 'server-1',
          conversationId: 'c1',
          userId: 'u1',
          body: 'in flight',
          createdAt: '2026-08-21T00:00:00Z',
          clientRef: ref,
        ),
      ]);

      final stored = await store.page('c1');
      expect(stored, hasLength(1));
      expect(stored.single.id, 'server-1');
      expect(stored.single.sendStatus, MessageSendStatus.sent);
      expect(await store.listUnsent(), isEmpty);
    },
  );

  test(
    'a history page without clientRef does not leave a second row',
    () async {
      const ref = 'client-1';
      await store.saveAll([
        ChatMessage(
          id: 'server-1',
          conversationId: 'c1',
          userId: 'u1',
          body: 'ok',
          createdAt: '2026-08-21T00:00:00Z',
          clientRef: ref,
        ),
      ]);
      await store.saveAll([
        ChatMessage(
          id: 'server-1',
          conversationId: 'c1',
          userId: 'u1',
          body: 'ok',
          createdAt: '2026-08-21T00:00:00Z',
        ),
      ]);

      final stored = await store.page('c1');
      expect(stored, hasLength(1));
      expect(stored.single.id, 'server-1');
    },
  );

  test('pending encrypted body is never searchable plaintext', () async {
    await store.saveAll([
      ChatMessage(
        id: 'p1',
        conversationId: 'c1',
        userId: 'u1',
        body: 'secret plaintext',
        createdAt: '2026-08-21T00:00:00Z',
        sendStatus: MessageSendStatus.sending,
        clientRef: 'p1',
        encryptedBody: 'Y2lwaGVy',
        encryptionVersion: 1,
      ),
    ]);

    expect(await store.search('secret'), isEmpty);
    final stored = (await store.page('c1')).single;
    expect(stored.body, isEmpty);
    expect(stored.encryptedBody, 'Y2lwaGVy');
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
