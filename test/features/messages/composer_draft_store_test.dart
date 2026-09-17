import 'package:ababilx/features/messages/data/local/composer_draft_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('drafts are isolated by account, conversation and thread', () async {
    final store = ComposerDraftStore();
    await store.write('account-a', 'conversation-1', 'root a');
    await store.write('account-b', 'conversation-1', 'root b');
    await store.write(
      'account-a',
      'conversation-1',
      'thread a',
      parentId: 'thread-1',
    );

    expect(await store.read('account-a', 'conversation-1'), 'root a');
    expect(await store.read('account-b', 'conversation-1'), 'root b');
    expect(
      await store.read('account-a', 'conversation-1', parentId: 'thread-1'),
      'thread a',
    );

    await store.clearConversation('account-a', 'conversation-1');
    expect(await store.read('account-a', 'conversation-1'), isEmpty);
    expect(
      await store.read('account-a', 'conversation-1', parentId: 'thread-1'),
      isEmpty,
    );
    expect(await store.read('account-b', 'conversation-1'), 'root b');

    await store.clearAll();
    expect(await store.read('account-b', 'conversation-1'), isEmpty);
  });
  test(
    'successful retry clears its bound draft after store recreation',
    () async {
      final store = ComposerDraftStore();
      await store.write('me', 'chat', 'failed text');
      await store.bindSend('me', 'chat', 'send-1', 'failed text');
      final restarted = ComposerDraftStore();
      await restarted.completeSend('me', 'chat', 'send-1');
      expect(await restarted.read('me', 'chat'), isEmpty);
    },
  );

  test(
    'late confirmation preserves newer draft, even identical text',
    () async {
      final store = ComposerDraftStore();
      await store.write('me', 'chat', 'hello');
      await store.bindSend('me', 'chat', 'send-1', 'hello');
      await store.write('me', 'chat', 'hello');
      await store.completeSend('me', 'chat', 'send-1');
      expect(await store.read('me', 'chat'), 'hello');
    },
  );

  test(
    'confirmation cannot clear another thread or another pending send',
    () async {
      final store = ComposerDraftStore();
      await store.write('me', 'chat', 'reply', parentId: 'thread');
      await store.bindSend('me', 'chat', 'send-2', 'reply', parentId: 'thread');
      await store.completeSend('me', 'chat', 'send-1', parentId: 'thread');
      await store.completeSend('me', 'chat', 'send-2');
      expect(await store.read('me', 'chat', parentId: 'thread'), 'reply');
      await store.completeSend('me', 'chat', 'send-2', parentId: 'thread');
      expect(await store.read('me', 'chat', parentId: 'thread'), isEmpty);
    },
  );
}
