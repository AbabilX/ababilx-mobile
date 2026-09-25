import 'package:ababilx/features/attachments/services/attachment_adopter.dart';
import 'package:ababilx/features/chat-lock/chat_lock_filter.dart';
import 'package:ababilx/features/chat-lock/data/chat_lock_index.dart';
import 'package:ababilx/features/chat-lock/data/chat_lock_secrets.dart';
import 'package:ababilx/features/messages/data/models/chat_models.dart';
import 'package:ababilx/features/notifications/chat/chat_notification_privacy.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

ChatConversation _dm(String id) => ChatConversation.fromJson({
  'id': id,
  'type': 'dm',
  'scope': 'personal',
  'created_at': '2026-09-25T10:00:00Z',
  'peer_user_id': 'peer-$id',
});

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('index round-trips, and the cache follows every write', () async {
    expect(await ChatLockIndex.read(), isEmpty);
    await ChatLockIndex.write({
      'a': ChatLockMethod.device,
      'b': ChatLockMethod.password,
    });
    expect(ChatLockIndex.cached, {
      'a': ChatLockMethod.device,
      'b': ChatLockMethod.password,
    });
    await ChatLockIndex.preload();
    expect(ChatLockIndex.cached['b'], ChatLockMethod.password);
    expect(await ChatLockIndex.isLocked('a'), isTrue);
    expect(await ChatLockIndex.isLocked('c'), isFalse);
    await ChatLockIndex.clearAll();
    expect(await ChatLockIndex.read(), isEmpty);
    expect(ChatLockIndex.cached, isEmpty);
  });

  test('a password opens only its own chat, and only when right', () async {
    await ChatLockSecrets.setPassword('a', 'correct horse');
    await ChatLockSecrets.setPassword('b', 'other');
    expect(await ChatLockSecrets.verify('a', 'correct horse'), isTrue);
    expect(await ChatLockSecrets.verify('a', 'Correct horse'), isFalse);
    expect(await ChatLockSecrets.verify('a', 'other'), isFalse);
    expect(await ChatLockSecrets.verify('c', 'correct horse'), isFalse);
    await ChatLockSecrets.remove('a');
    expect(await ChatLockSecrets.verify('a', 'correct horse'), isFalse);
  });

  test('clearAll drops every password hash', () async {
    await ChatLockSecrets.setPassword('a', 'one');
    await ChatLockSecrets.setPassword('b', 'two');
    await ChatLockSecrets.clearAll();
    expect(await ChatLockSecrets.verify('a', 'one'), isFalse);
    expect(await ChatLockSecrets.verify('b', 'two'), isFalse);
    final stored = await const FlutterSecureStorage().readAll();
    expect(stored.keys.where((k) => k.startsWith('chat_lock_pw_v1_')), isEmpty);
  });

  test('the password is never stored in the clear', () async {
    await ChatLockSecrets.setPassword('a', 'correct horse');
    final stored = await const FlutterSecureStorage().readAll();
    expect(stored.values.join(), isNot(contains('correct horse')));
    expect(stored.values.single, startsWith('v1:'));
  });

  test('a locked chat always hides its notification text', () async {
    expect(await ChatNotificationPrivacy.isHidden('a'), isFalse);
    await ChatNotificationPrivacy.setChosen('a', true);
    expect(await ChatNotificationPrivacy.isHidden('a'), isTrue);
    await ChatNotificationPrivacy.setChosen('a', false);
    expect(await ChatNotificationPrivacy.isHidden('a'), isFalse);
    await ChatLockIndex.write({'a': ChatLockMethod.device});
    expect(await ChatNotificationPrivacy.isHidden('a'), isTrue);
    expect(await ChatNotificationPrivacy.isHidden(''), isFalse);
  });

  test('lists leave locked chats out', () {
    final all = [_dm('a'), _dm('b'), _dm('c')];
    expect(withoutLockedChats(all, const {}), same(all));
    expect(
      withoutLockedChats(all, {'b': ChatLockMethod.password}).map((c) => c.id),
      ['a', 'c'],
    );
  });

  test('a fresh upload names its conversation in the URL', () {
    const id = '0f8fad5b-d9cb-469f-a165-70867728950e';
    expect(
      uploadConversationId('https://cdn.ababilx.com/chat/$id/9b2c.jpg'),
      id,
    );
    expect(
      uploadConversationId('https://cdn.ababilx.com/teams/t1/chat/9b2c.jpg'),
      isNull,
    );
    expect(uploadConversationId(''), isNull);
  });
}
