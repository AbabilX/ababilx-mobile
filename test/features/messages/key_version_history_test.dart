import 'package:ababilx/core/storage/secure_storage.dart';
import 'package:ababilx/features/messages/data/chat_repository.dart';
import 'package:ababilx/features/messages/data/local/chat_key_cache.dart';
import 'package:ababilx/features/messages/data/local/chat_local_db.dart';
import 'package:ababilx/features/messages/data/models/chat_message.dart';
import 'package:ababilx/features/messages/message_e2ee/message_vault.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// A server that keeps every key version, the way the real one does, and
/// answers `GET .../e2ee-key` with the newest alone.
class _Repository implements ChatRepository {
  Map<String, dynamic> vault = {'exists': false};
  Map<String, dynamic>? selfPublicKey;
  final envelopes = <int, Map<String, dynamic>>{};
  bool offline = false;
  int versionFetches = 0;

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
    Map<String, dynamic> sealed,
  ) async {
    _online();
    final version = envelopes.length + 1;
    envelopes[version] = Map<String, dynamic>.from(sealed['me'] as Map);
    return {'key_version': version, 'envelope': envelopes[version]};
  }

  @override
  Future<Map<String, dynamic>> getE2eeConversationKey(String id) async {
    _online();
    if (envelopes.isEmpty) return {'exists': false};
    final newest = envelopes.keys.reduce((a, b) => a > b ? a : b);
    return {
      'exists': true,
      'key': {'key_version': newest, 'envelope': envelopes[newest]},
      'rekey_required': false,
      'missing_member_ids': const [],
      'gaps': const [],
    };
  }

  @override
  Future<Map<String, dynamic>> getE2eeConversationKeyVersions(
    String id,
    List<int> versions,
  ) async {
    _online();
    versionFetches++;
    return {
      'envelopes': [
        for (final v in versions)
          if (envelopes[v] != null)
            {'key_version': v, 'envelope': envelopes[v]},
      ],
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Storage implements SecureStorage {
  String? identity;
  final pendingRecovery = <String, String>{};
  final recoveryCodes = <String, String>{};
  @override
  Future<String?> readMessageVaultIdentity() async => identity;
  @override
  Future<void> writeMessageVaultIdentity(String value) async =>
      identity = value;
  @override
  Future<void> deleteMessageVaultIdentity() async => identity = null;
  @override
  Future<String?> readPendingRecovery(String userId) async =>
      pendingRecovery[userId];
  @override
  Future<void> writePendingRecovery(String userId, String value) async =>
      pendingRecovery[userId] = value;
  @override
  Future<void> deletePendingRecovery(String userId) async =>
      pendingRecovery.remove(userId);
  @override
  Future<String?> readRecoveryCode(String identityId) async =>
      recoveryCodes[identityId];
  @override
  Future<void> writeRecoveryCode(String identityId, String code) async =>
      recoveryCodes[identityId] = code;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ChatMessage _sealed(String id, EncryptedDmPayload payload) => ChatMessage(
  id: id,
  conversationId: 'group',
  userId: 'me',
  body: '',
  createdAt: '2026-09-13T00:00:00Z',
  encryptedBody: payload.encryptedBody,
  encryptionNonce: payload.nonce,
  encryptionVersion: 1,
  encryptionKeyVersion: payload.keyVersion,
);

ChatKeyCache _freshCache() {
  final db = ChatLocalDb.forTesting(NativeDatabase.memory());
  addTearDown(db.close);
  return ChatKeyCache(db);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Two databases per test is the point: a second, empty one is the reinstall.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late _Repository repo;
  late _Storage storage;
  late EncryptedDmPayload before;
  late EncryptedDmPayload after;

  // A group that rotated once: the reported bug needs nothing more.
  setUp(() async {
    repo = _Repository();
    storage = _Storage();
    final phone = MessageVault(repo, storage, _freshCache());
    await phone.ensureIdentity();
    before = await phone.encryptNew(
      conversationId: 'group',
      text: 'written before the rotation',
      currentUserId: 'me',
    );
    after = await phone.rekeyAndEncrypt(
      conversationId: 'group',
      text: 'written after it',
      currentUserId: 'me',
    );
    expect(after.keyVersion, greaterThan(before.keyVersion));
  });

  test('a reinstall reads messages sealed before the last rotation', () async {
    // Same identity (what the recovery code restores), empty local database.
    final reinstalled = MessageVault(repo, storage, _freshCache());
    expect(await reinstalled.restoreTrustedIdentity(), isTrue);

    final old = await reinstalled.decryptMessage(_sealed('a', before), 'me');
    final latest = await reinstalled.decryptMessage(_sealed('b', after), 'me');
    expect(old.body, 'written before the rotation');
    expect(latest.body, 'written after it');
  });

  test('a page under one retired version asks the server once', () async {
    final reinstalled = MessageVault(repo, storage, _freshCache());
    await reinstalled.restoreTrustedIdentity();

    final page = [for (var i = 0; i < 40; i++) _sealed('m$i', before)];
    final read = await reinstalled.decryptMessages(page, 'me');
    expect(read.map((m) => m.body).toSet(), {'written before the rotation'});
    expect(repo.versionFetches, 1);
  });

  test(
    'a fetched version is stored, so the next launch needs no network',
    () async {
      final cache = _freshCache();
      final reinstalled = MessageVault(repo, storage, cache);
      await reinstalled.restoreTrustedIdentity();
      await reinstalled.decryptMessage(_sealed('a', before), 'me');

      repo.offline = true;
      final relaunched = MessageVault(repo, storage, cache);
      await relaunched.restoreTrustedIdentity();
      final old = await relaunched.decryptMessage(_sealed('a', before), 'me');
      expect(old.body, 'written before the rotation');
    },
  );

  test(
    'a version the server does not hold fails once, not per message',
    () async {
      // Lost to an identity reset, say, and not backfilled yet.
      repo.envelopes.remove(before.keyVersion);
      final reinstalled = MessageVault(repo, storage, _freshCache());
      await reinstalled.restoreTrustedIdentity();

      final first = await reinstalled.decryptMessage(
        _sealed('a', before),
        'me',
      );
      final again = await reinstalled.decryptMessage(
        _sealed('b', before),
        'me',
      );
      expect(first.body, 'Unable to decrypt this message');
      expect(again.body, 'Unable to decrypt this message');
      expect(repo.versionFetches, 1);
    },
  );
}
