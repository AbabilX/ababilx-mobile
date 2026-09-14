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
}
