import 'dart:convert';

import 'package:ababilx/core/network/recent_sign_in.dart';
import 'package:ababilx/features/messages/data/chat_recovery_api.dart';
import 'package:ababilx/features/messages/data/chat_repository.dart';
import 'package:ababilx/features/messages/message_e2ee/message_vault.dart';
import 'package:ababilx/features/messages/message_e2ee/new_chat_setup.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'recovery_session_test.dart'
    show MemoryRecoveryStorage, MemoryRecoveryRepo, MemoryRecoveryApi;

/// Refuses for want of a recent sign-in until [refusing] is cleared.
class _NeedsSignInApi extends MemoryRecoveryApi {
  _NeedsSignInApi(super.store, super.repo, this.outcome);
  final ReauthOutcome outcome;
  bool refusing = true;
  int refusals = 0;
  @override
  Future<void> startSession(Map<String, dynamic> body) async {
    if (refusing) {
      refusals++;
      throw RecentSignInRequired(outcome);
    }
    await super.startSession(body);
  }
}

void main() {
  Future<
    ({
      ProviderContainer container,
      MemoryRecoveryStorage storage,
      MessageVault vault,
      _NeedsSignInApi api,
    })
  >
  started(ReauthOutcome outcome) async {
    final storage = MemoryRecoveryStorage();
    final repo = MemoryRecoveryRepo(storage);
    final vault = MessageVault(repo, storage);
    final api = _NeedsSignInApi(storage, repo, outcome);
    final container = ProviderContainer(
      overrides: [
        chatRepositoryProvider.overrideWithValue(repo),
        chatRecoveryApiProvider.overrideWithValue(api),
        messageVaultProvider.overrideWithValue(vault),
      ],
    );
    addTearDown(container.dispose);
    container.read(newChatSetupProvider.notifier).start(userId: 'u');
    await settle(container);
    return (container: container, storage: storage, vault: vault, api: api);
  }

  test(
    'a cancelled sign-in asks to sign in again and keeps the candidate',
    () async {
      final run = await started(ReauthOutcome.cancelled);
      final setup = run.container.read(newChatSetupProvider.notifier);
      expect(
        run.container.read(newChatSetupProvider),
        NewChatSetupState.needsSignIn,
      );
      expect(setup.signOutToContinue, isFalse, reason: 'a retry asks again');
      expect(run.api.refusals, 1, reason: 'no automatic loop');
      final candidate = await run.storage.readPendingRecovery('u');
      expect(candidate, isNotNull);
      expect(run.vault.isUnlocked, isFalse, reason: 'nothing was adopted');

      run.api.refusing = false;
      setup.retry();
      await settle(run.container);
      expect(run.container.read(newChatSetupProvider), NewChatSetupState.ready);
      expect(run.api.requests, hasLength(1));
      expect(
        run.api.requests.single['public_key'],
        ((jsonDecode(candidate!) as Map)['body'] as Map)['public_key'],
        reason: 'the same saved key is sent, never a second one',
      );
    },
  );

  test('an email account is sent to sign in again', () async {
    final run = await started(ReauthOutcome.notSupported);
    expect(
      run.container.read(newChatSetupProvider),
      NewChatSetupState.needsSignIn,
    );
    expect(
      run.container.read(newChatSetupProvider.notifier).signOutToContinue,
      isTrue,
    );
  });

  test('offline during the sign-in is an ordinary retry', () async {
    final run = await started(ReauthOutcome.unavailable);
    expect(run.container.read(newChatSetupProvider), NewChatSetupState.failed);
  });
}

Future<void> settle(ProviderContainer container) async {
  for (
    var i = 0;
    i < 100 &&
        container.read(newChatSetupProvider) == NewChatSetupState.running;
    i++
  ) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}
