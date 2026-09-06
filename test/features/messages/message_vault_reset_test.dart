import 'dart:convert';

import 'package:ababilx/core/storage/secure_storage.dart';
import 'package:ababilx/features/messages/data/chat_repository.dart';
import 'package:ababilx/features/messages/message_e2ee/message_vault.dart';
import 'package:ababilx/features/messages/message_e2ee/recovery_key.dart';
import 'package:flutter_test/flutter_test.dart';

class _Repository implements ChatRepository {
  Map<String, dynamic> status = {'exists': false};
  bool reject = false;
  bool loseResponse = false;
  int resets = 0;

  @override
  Future<Map<String, dynamic>> getE2eeVault() async => status;

  @override
  Future<void> resetE2eeVault(
    String code,
    Map<String, dynamic> public,
    Map<String, dynamic> recovery,
  ) async {
    resets++;
    if (reject) throw StateError('rejected');
    status = {
      'exists': true,
      'has_recovery': true,
      'vault': {'public_key': public, 'recovery': recovery},
    };
    if (loseResponse) throw StateError('response lost');
  }

  @override
  Future<void> putE2eeRecoveryVault(
    Map<String, dynamic> public,
    Map<String, dynamic> recovery,
  ) async {
    status = {
      'exists': true,
      'has_recovery': true,
      'vault': {'public_key': public, 'recovery': recovery},
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Storage implements SecureStorage {
  String? identity;
  bool failWrite = false;
  @override
  Future<String?> readMessageVaultIdentity() async => identity;
  @override
  Future<void> writeMessageVaultIdentity(String value) async {
    if (failWrite) throw StateError('device storage unavailable');
    identity = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'new account sets up; another phone offers recovery and restores identity',
    () async {
      final repo = _Repository();
      final first = MessageVault(repo, _Storage());
      expect(await first.ensureIdentity(), VaultIdentityState.setup);
      final code = first.takePendingRecoveryCode()!;
      final second = MessageVault(repo, _Storage());
      expect(await second.ensureIdentity(), VaultIdentityState.unlock);
      await second.unlockWithRecoveryCode(code);
      expect(second.publicIdentity, first.publicIdentity);
      expect(second.isUnlocked, isTrue);
    },
  );

  test(
    'lost reset response reconciles and the new code actually recovers',
    () async {
      final repo = _Repository()..loseResponse = true;
      final storage = _Storage();
      final vault = MessageVault(repo, storage);
      final code = await vault.startFreshIdentity('123ABC456');
      final remote = repo.status['vault'] as Map;
      final private = await RecoveryKey.unwrap(
        RecoveryVault.fromJson(Map<String, dynamic>.from(remote['recovery'])),
        RecoveryKey.parse(code)!,
      );
      final saved = jsonDecode(storage.identity!) as Map;
      expect(saved['private_key'], private);
      expect(vault.isUnlocked, isTrue);
      expect(repo.resets, 1);
    },
  );

  test('rejected reset leaves the device identity unchanged', () async {
    final repo = _Repository()..reject = true;
    final storage = _Storage()..identity = 'unchanged';
    final vault = MessageVault(repo, storage);
    await expectLater(vault.startFreshIdentity('123ABC456'), throwsStateError);
    expect(storage.identity, 'unchanged');
    expect(vault.isUnlocked, isFalse);
  });

  test(
    'storage failure retries adoption without spending a second reset',
    () async {
      final repo = _Repository();
      final storage = _Storage()..failWrite = true;
      final vault = MessageVault(repo, storage);
      await expectLater(
        vault.startFreshIdentity('123ABC456'),
        throwsStateError,
      );
      storage.failWrite = false;
      final code = await vault.startFreshIdentity('123ABC456');
      expect(repo.resets, 1);
      expect(RecoveryKey.parse(code), isNotNull);
      expect(storage.identity, isNotNull);
    },
  );
}
