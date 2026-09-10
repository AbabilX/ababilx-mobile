import 'package:ababilx/core/storage/secure_storage.dart';
import 'package:ababilx/features/messages/data/chat_repository.dart';
import 'package:ababilx/features/messages/data/local/chat_key_cache.dart';
import 'package:ababilx/features/messages/data/local/chat_local_db.dart';
import 'package:ababilx/features/messages/data/models/chat_message.dart';
import 'package:ababilx/features/messages/message_e2ee/message_vault.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// A server that can be unplugged. Everything a real one answers is here, and
/// once [offline] is set every call throws the way a dead connection does.
class _Repository implements ChatRepository {
  Map<String, dynamic> vault = {'exists': false};
  Map<String, dynamic>? selfPublicKey;
  Map<String, dynamic>? storedEnvelope;
  int keyVersion = 0;
  bool offline = false;
  int keyFetches = 0;

  void _online() {
    if (offline) throw StateError('network unreachable');
  }

  @override
  Future<Map<String, dynamic>> getE2eeVault() async {
    _online();
    return vault;
  }

  @override
  Future<void> putE2eeRecoveryVault(
    Map<String, dynamic> public,
    Map<String, dynamic> recovery,
  ) async {
    _online();
    selfPublicKey = public;
    vault = {
      'exists': true,
      'has_recovery': true,
      'vault': {'public_key': public, 'recovery': recovery},
    };
  }

  @override
  Future<Map<String, dynamic>> getE2eeConversationMembers(String id) async {
    _online();
    return {
      'members': [
        {'user_id': 'me', 'public_key': selfPublicKey},
      ],
      'unready_member_ids': const [],
    };
  }

  @override
  Future<Map<String, dynamic>> createE2eeConversationKey(
    String id,
    Map<String, dynamic> envelopes,
  ) async {
    _online();
    keyVersion++;
    storedEnvelope = Map<String, dynamic>.from(envelopes['me'] as Map);
    return {'key_version': keyVersion, 'envelope': storedEnvelope};
  }

  @override
  Future<Map<String, dynamic>> getE2eeConversationKey(String id) async {
    _online();
    keyFetches++;
    if (storedEnvelope == null) return {'exists': false};
    return {
      'exists': true,
      'key': {'key_version': keyVersion, 'envelope': storedEnvelope},
      'rekey_required': false,
      'missing_member_ids': const [],
      'gaps': const [],
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Storage implements SecureStorage {
  String? identity;
  @override
  Future<String?> readMessageVaultIdentity() async => identity;
  @override
  Future<void> writeMessageVaultIdentity(String value) async =>
      identity = value;
  @override
  Future<void> deleteMessageVaultIdentity() async => identity = null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ChatMessage _sealed(EncryptedDmPayload payload) => ChatMessage(
  id: 'm1',
  conversationId: 'chat',
  userId: 'me',
  body: '',
  createdAt: '2026-09-10T00:00:00Z',
  encryptedBody: payload.encryptedBody,
  encryptionNonce: payload.nonce,
  encryptionVersion: 1,
  encryptionKeyVersion: payload.keyVersion,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ChatLocalDb db;
  late ChatKeyCache cache;
  late _Repository repo;
  late _Storage storage;

  setUp(() {
    db = ChatLocalDb.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    cache = ChatKeyCache(db);
    repo = _Repository();
    storage = _Storage();
  });

  test(
    'a message written online is readable on a cold start with no network',
    () async {
      final online = MessageVault(repo, storage, cache);
      await online.ensureIdentity();
      final payload = await online.encryptNew(
        conversationId: 'chat',
        text: 'see you at eight',
        currentUserId: 'me',
      );

      // A different vault instance is a fresh launch: nothing in memory, only
      // the OS keystore and the local database.
      repo.offline = true;
      final relaunched = MessageVault(repo, storage, cache);

      // An unreachable server must not tear down an identity this device holds.
      expect(await relaunched.restoreTrustedIdentity(), isTrue);
      expect(relaunched.isUnlocked, isTrue);

      final read = await relaunched.decryptMessage(_sealed(payload), 'me');
      expect(read.body, 'see you at eight');
    },
  );

  test(
    'a cold start with a connection reads from disk without asking for the key',
    () async {
      final online = MessageVault(repo, storage, cache);
      await online.ensureIdentity();
      final payload = await online.encryptNew(
        conversationId: 'chat',
        text: 'hello',
        currentUserId: 'me',
      );

      final before = repo.keyFetches;
      final relaunched = MessageVault(repo, storage, cache);
      await relaunched.restoreTrustedIdentity();
      final read = await relaunched.decryptMessage(_sealed(payload), 'me');

      expect(read.body, 'hello');
      expect(repo.keyFetches, before, reason: 'the stored envelope answers it');
    },
  );

  test('a message sealed before a rotation stays readable offline', () async {
    final online = MessageVault(repo, storage, cache);
    await online.ensureIdentity();
    final first = await online.encryptNew(
      conversationId: 'chat',
      text: 'the old one',
      currentUserId: 'me',
    );
    // Rotating replaces the only envelope the server will ever hand out, so
    // the version the first message was sealed with now exists on this device
    // alone.
    final second = await online.rekeyAndEncrypt(
      conversationId: 'chat',
      text: 'the new one',
      currentUserId: 'me',
    );
    expect(second.keyVersion, greaterThan(first.keyVersion));

    repo.offline = true;
    final relaunched = MessageVault(repo, storage, cache);
    await relaunched.restoreTrustedIdentity();

    expect(
      (await relaunched.decryptMessage(_sealed(first), 'me')).body,
      'the old one',
    );
    expect(
      (await relaunched.decryptMessage(_sealed(second), 'me')).body,
      'the new one',
    );
  });

  test(
    'no stored envelope offline still reports the failure honestly',
    () async {
      final online = MessageVault(repo, storage, cache);
      await online.ensureIdentity();
      final payload = await online.encryptNew(
        conversationId: 'chat',
        text: 'unreachable',
        currentUserId: 'me',
      );
      await cache.clearAll();

      repo.offline = true;
      final relaunched = MessageVault(repo, storage, cache);
      await relaunched.restoreTrustedIdentity();
      final read = await relaunched.decryptMessage(_sealed(payload), 'me');
      expect(read.body, 'Unable to decrypt this message');
    },
  );

  test('the cache is version-exact and clears per conversation', () async {
    await cache.save('chat', 1, {'ciphertext': 'a'});
    await cache.save('chat', 2, {'ciphertext': 'b'});
    await cache.save('other', 1, {'ciphertext': 'c'});

    expect((await cache.read('chat', 1))!['ciphertext'], 'a');
    expect((await cache.read('chat', 3)), isNull);
    expect((await cache.newest('chat'))!.version, 2);

    await cache.clearConversation('chat');
    expect(await cache.read('chat', 1), isNull);
    expect((await cache.read('other', 1))!['ciphertext'], 'c');
  });
}
