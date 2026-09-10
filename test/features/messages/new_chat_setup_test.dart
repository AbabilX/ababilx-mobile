import 'dart:async';
import 'package:ababilx/core/localization/app_translations.dart';
import 'package:ababilx/features/messages/data/chat_recovery_api.dart';
import 'package:ababilx/features/messages/data/chat_repository.dart';
import 'package:ababilx/features/messages/message_e2ee/message_entry_ready.dart';
import 'package:ababilx/features/messages/message_e2ee/message_recovery_screen.dart';
import 'package:ababilx/features/messages/message_e2ee/message_vault.dart';
import 'package:ababilx/features/messages/message_e2ee/new_chat_setup.dart';
import 'package:ababilx/features/messages/providers/chat_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'recovery_session_test.dart'
    show MemoryRecoveryStorage, MemoryRecoveryRepo, MemoryRecoveryApi;

class _Chat extends ChatNotifier {
  @override
  ChatState build() => const ChatState(currentUserId: 'u');
  @override
  Future<String> ensureCurrentUserId() async => 'u';
}

class _SlowApi extends MemoryRecoveryApi {
  _SlowApi(super.store, super.repo);
  final release = Completer<void>();
  @override
  Future<void> startSession(Map<String, dynamic> body) async {
    await release.future;
    await super.startSession(body);
  }
}

class _FailOnceApi extends MemoryRecoveryApi {
  _FailOnceApi(super.store, super.repo);
  bool fail = true;
  @override
  Future<void> startSession(Map<String, dynamic> body) async {
    if (fail) {
      fail = false;
      throw StateError('offline');
    }
    await super.startSession(body);
  }
}

void main() {
  testWidgets('Start new chat opens chat before recovery setup finishes', (
    tester,
  ) async {
    final storage = MemoryRecoveryStorage();
    final repo = MemoryRecoveryRepo(storage)
      ..remote = {
        'exists': true,
        'has_history': true,
        'has_recovery': true,
        'vault': {
          'public_key': {'x': 'old', 'y': 'old'},
        },
      };
    final vault = MessageVault(repo, storage);
    final api = _SlowApi(storage, repo);
    final container = ProviderContainer(
      overrides: [
        appLanguageProvider.overrideWithValue('en'),
        chatProvider.overrideWith(_Chat.new),
        chatRepositoryProvider.overrideWithValue(repo),
        chatRecoveryApiProvider.overrideWithValue(api),
        messageVaultProvider.overrideWithValue(vault),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) => ref.watch(messageEntryReadyProvider)
                ? const Scaffold(body: Text('Chat window'))
                : const MessageRecoveryScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start new chat'));
    await tester.pump();
    expect(find.text('Chat window'), findsOneWidget);
    expect(container.read(newChatSetupProvider), NewChatSetupState.running);
    expect(vault.isUnlocked, isFalse);
    await tester.runAsync(() async {
      api.release.complete();
      for (
        var i = 0;
        i < 100 &&
            container.read(newChatSetupProvider) == NewChatSetupState.running;
        i++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pump();
    expect(container.read(newChatSetupProvider), NewChatSetupState.ready);
    expect(vault.isUnlocked, isTrue);
    expect(await vault.hasStoredRecoveryCode(), isTrue);
    expect(api.requests, hasLength(1));
    expect(api.requests.single['clear_history'], isTrue);
    await tester.pumpWidget(const SizedBox());
  });
  test('background failure can retry the same saved candidate', () async {
    final storage = MemoryRecoveryStorage();
    final repo = MemoryRecoveryRepo(storage);
    final vault = MessageVault(repo, storage);
    final api = _FailOnceApi(storage, repo);
    final container = ProviderContainer(
      overrides: [
        chatRepositoryProvider.overrideWithValue(repo),
        chatRecoveryApiProvider.overrideWithValue(api),
        messageVaultProvider.overrideWithValue(vault),
      ],
    );
    addTearDown(container.dispose);
    Future<void> settle() async {
      for (
        var i = 0;
        i < 100 &&
            container.read(newChatSetupProvider) == NewChatSetupState.running;
        i++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    }

    final setup = container.read(newChatSetupProvider.notifier);
    setup.start(userId: 'u');
    await settle();
    expect(container.read(newChatSetupProvider), NewChatSetupState.failed);
    final candidate = await storage.readPendingRecovery('u');
    expect(candidate, isNotNull);
    expect(await vault.restoreTrustedIdentityOffline(), isFalse);
    setup.retry();
    await settle();
    expect(container.read(newChatSetupProvider), NewChatSetupState.ready);
    expect(await storage.readPendingRecovery('u'), isNull);
    expect(await vault.hasStoredRecoveryCode(), isTrue);
    expect(api.requests, hasLength(1));
    expect(api.requests.single['clear_history'], isTrue);
  });
}
