import 'dart:convert';
import 'package:ababilx/core/network/api_client.dart';
import 'package:ababilx/core/storage/secure_storage.dart';
import 'package:ababilx/features/messages/data/chat_repository.dart';
import 'package:ababilx/features/messages/data/chat_recovery_api.dart';
import 'package:ababilx/features/messages/message_e2ee/message_vault.dart';
import 'package:ababilx/features/messages/message_e2ee/recovery_key.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class MemoryRecoveryStorage extends SecureStorage {
  MemoryRecoveryStorage() : super(const FlutterSecureStorage());
  final values = <String, String>{};
  bool failIdentityWrite = false;
  @override
  Future<String?> readMessageVaultIdentity() async => values['identity'];
  @override
  Future<void> writeMessageVaultIdentity(String value) async {
    if (failIdentityWrite) throw StateError('device write interrupted');
    values['identity'] = value;
  }

  @override
  Future<String?> readPendingRecovery(String id) async => values['pending:$id'];
  @override
  Future<void> writePendingRecovery(String id, String value) async {
    values['pending:$id'] = value;
  }

  @override
  Future<void> deletePendingRecovery(String id) async {
    values.remove('pending:$id');
  }

  @override
  Future<String?> readRecoveryCode(String id) async => values['code:$id'];
  @override
  Future<void> writeRecoveryCode(String id, String code) async {
    values['code:$id'] = code;
  }
}

class MemoryRecoveryRepo extends ChatRepository {
  MemoryRecoveryRepo(SecureStorage store) : super(ApiClient(store));
  Map<String, dynamic> remote = {'exists': false};
  @override
  Future<Map<String, dynamic>> getE2eeVault() async => remote;
  @override
  Future<void> putE2eeRecoveryVault(
    Map<String, dynamic> public,
    Map<String, dynamic> recovery,
  ) async {
    remote = {
      'exists': true,
      'vault': {'public_key': public, 'recovery': recovery},
    };
  }
}

class MemoryRecoveryApi extends ChatRecoveryApi {
  MemoryRecoveryApi(SecureStorage store, this.repo) : super(ApiClient(store));
  final MemoryRecoveryRepo repo;
  final requests = <Map<String, dynamic>>[];
  bool loseResponse = false;
  @override
  Future<void> startSession(Map<String, dynamic> body) async {
    requests.add(body);
    await repo.putE2eeRecoveryVault(
      Map<String, dynamic>.from(body['public_key'] as Map),
      {
        'wrapped_key': body['wrapped_key'],
        'salt': body['salt'],
        'version': body['version'],
      },
    );
    if (loseResponse) throw StateError('connection dropped after commit');
  }
}

void main() {
  test(
    'code persists only on phone and can be read locally after unlocking',
    () async {
      final store = MemoryRecoveryStorage();
      final repo = MemoryRecoveryRepo(store);
      final api = MemoryRecoveryApi(store, repo);
      final vault = MessageVault(repo, store);
      await vault.startSession(userId: 'u', api: api);
      expect(vault.isUnlocked, isTrue);
      expect(vault.takePendingRecoveryCode(), isNull);
      final code = (await vault.readStoredRecoveryCode())!;
      expect(RecoveryKey.parse(code)?.length, 32);
      expect(jsonEncode(api.requests.single).contains(code), isFalse);
      expect(
        api.requests.single.keys,
        unorderedEquals(['public_key', 'wrapped_key', 'salt', 'version']),
      );
      vault.lock();
      await expectLater(vault.readStoredRecoveryCode(), throwsStateError);
      final restarted = MessageVault(repo, store);
      expect(await restarted.restoreTrustedIdentityOffline(), isTrue);
      expect(await restarted.readStoredRecoveryCode(), code);
    },
  );
  test('lost response reconciles without generating another code', () async {
    final store = MemoryRecoveryStorage();
    final repo = MemoryRecoveryRepo(store);
    final api = MemoryRecoveryApi(store, repo)..loseResponse = true;
    final vault = MessageVault(repo, store);
    await vault.startSession(userId: 'u', api: api);
    expect(vault.isUnlocked, isTrue);
    expect(await store.readPendingRecovery('u'), isNull);
    expect(api.requests, hasLength(1));
  });
  test(
    'process interruption resumes exact candidate from secure storage',
    () async {
      final store = MemoryRecoveryStorage()..failIdentityWrite = true;
      final repo = MemoryRecoveryRepo(store);
      final api = MemoryRecoveryApi(store, repo);
      await expectLater(
        MessageVault(repo, store).startSession(userId: 'u', api: api),
        throwsStateError,
      );
      expect(await store.readPendingRecovery('u'), isNotNull);
      final first = jsonEncode(api.requests.single);
      store.failIdentityWrite = false;
      final restarted = MessageVault(repo, store);
      expect(await restarted.resumePendingSession('u', api), isTrue);
      expect(jsonEncode(api.requests.last), first);
      expect(await restarted.readStoredRecoveryCode(), isNotNull);
    },
  );
  test(
    'entering recovery code on another phone stores it only on that phone',
    () async {
      final store = MemoryRecoveryStorage();
      final repo = MemoryRecoveryRepo(store);
      final vault = MessageVault(repo, store);
      await vault.startSession(
        userId: 'u',
        api: MemoryRecoveryApi(store, repo),
      );
      final code = (await vault.readStoredRecoveryCode())!;
      final other = MessageVault(repo, MemoryRecoveryStorage());
      await other.unlockWithRecoveryCode(code);
      expect(await other.readStoredRecoveryCode(), code);
    },
  );
}
