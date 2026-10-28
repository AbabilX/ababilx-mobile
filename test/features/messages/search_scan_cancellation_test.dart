import 'dart:async';
import 'package:ababilx/features/messages/data/local/chat_local_db.dart';
import 'package:ababilx/features/messages/data/local/chat_message_store.dart';
import 'package:ababilx/features/messages/data/models/chat_message.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class _Store extends ChatMessageStore {
  _Store(super.db);
  int reads = 0;
  @override
  Future<List<ChatMessage>> search(
    String query, {
    int limit = 30,
    String? conversationId,
  }) async => [];
  @override
  Future<List<ChatMessage>> encryptedPage({
    int limit = 200,
    int offset = 0,
    String? conversationId,
  }) async {
    reads++;
    if (offset >= 600) return [];
    return List.generate(
      limit,
      (i) => ChatMessage(
        id: '${offset + i}',
        conversationId: 'c',
        userId: 'u',
        body: '',
        createdAt: '',
        encryptedBody: 'cipher',
        encryptionVersion: 1,
      ),
    );
  }
}

void main() {
  late ChatLocalDb db;
  late _Store store;
  setUp(() {
    db = ChatLocalDb.forTesting(NativeDatabase.memory());
    store = _Store(db);
  });
  tearDown(() => db.close());

  test('superseded scan stops after the current decrypt batch', () async {
    var current = true;
    var decrypts = 0;
    final results = await LocalMessageSearch(store, (rows) async {
      decrypts++;
      current = false;
      return rows.map((m) => m.copyWith(body: 'other')).toList();
    }).search('missing', isCurrent: () => current);
    expect(results, isEmpty);
    expect(store.reads, 1);
    expect(decrypts, 1);
  });
  test('locked vault skips encrypted database pages', () async {
    final results = await LocalMessageSearch(
      store,
      (_) async => throw StateError('must not decrypt'),
    ).search('missing', searchEncrypted: false);
    expect(results, isEmpty);
    expect(store.reads, 0);
  });
  test('active search keeps complete coverage past the first page', () async {
    final results = await LocalMessageSearch(
      store,
      (rows) async => rows
          .map((m) => m.copyWith(body: m.id == '599' ? 'needle' : 'other'))
          .toList(),
    ).search('needle');
    expect(results.map((m) => m.id), ['599']);
    expect(store.reads, 4);
  });
  test('cancellation while a page decrypts discards its results', () async {
    final started = Completer<void>();
    final release = Completer<void>();
    var current = true;
    final scan = LocalMessageSearch(store, (rows) async {
      started.complete();
      await release.future;
      return rows.map((m) => m.copyWith(body: 'needle')).toList();
    }).search('needle', isCurrent: () => current);
    await started.future;
    current = false;
    release.complete();
    expect(await scan, isEmpty);
    expect(store.reads, 1);
  });
}
