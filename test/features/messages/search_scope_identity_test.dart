import 'dart:async';
import 'package:ababilx/core/network/api_client.dart';
import 'package:ababilx/core/storage/secure_storage.dart';
import 'package:ababilx/features/messages/chat-list/chat_search.dart';
import 'package:ababilx/features/messages/data/chat_repository.dart';
import 'package:ababilx/features/messages/data/local/chat_local_db.dart';
import 'package:ababilx/features/messages/data/local/chat_message_store.dart';
import 'package:ababilx/features/messages/data/models/chat_models.dart';
import 'package:ababilx/features/messages/message_e2ee/message_vault.dart';
import 'package:ababilx/features/messages/providers/chat_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'no_typing_override.dart';

const _storage = SecureStorage(FlutterSecureStorage());

class _Repo extends ChatRepository {
  _Repo() : super(ApiClient(_storage));
  final calls = <Completer<List<ChatMessage>>>[];
  @override
  Future<List<ChatMessage>> searchMessages(String q, {int limit = 20}) {
    final call = Completer<List<ChatMessage>>();
    calls.add(call);
    return call.future;
  }
}

class _Chat extends ChatNotifier {
  _Chat(this.store, this.repository);
  final ChatMessageStore store;
  final _Repo repository;
  @override
  ChatState build() => const ChatState(currentUserId: 'u');
  @override
  ChatMessageStore get messageStore => store;
  @override
  ChatRepository get repo => repository;
}

class _RecordingChat extends ChatNotifier {
  final scopes = <String?>[];
  @override
  ChatState build() => const ChatState();
  @override
  Future<void> searchMessages(String q, {String? conversationId}) async {
    if (q.isNotEmpty) scopes.add(conversationId);
    state = state.copyWith(
      searchQuery: q,
      searchIdentity: (query: q, conversationId: conversationId),
    );
  }
}

void main() {
  test(
    'equal query in another scope ignores an older network answer',
    () async {
      final db = ChatLocalDb.forTesting(NativeDatabase.memory());
      final repo = _Repo();
      final container = ProviderContainer(
        overrides: [
          chatProvider.overrideWith(() => _Chat(ChatMessageStore(db), repo)),
          messageVaultProvider.overrideWithValue(MessageVault(repo, _storage)),
        ],
      );
      try {
        final chat = container.read(chatProvider.notifier);
        final first = chat.searchMessages('deploy', conversationId: 'a');
        while (repo.calls.isEmpty) {
          await Future<void>.delayed(Duration.zero);
        }
        final second = chat.searchMessages('deploy');
        while (repo.calls.length < 2) {
          await Future<void>.delayed(Duration.zero);
        }
        repo.calls[1].complete([
          const ChatMessage(
            id: 'global',
            conversationId: 'b',
            userId: 'u',
            body: 'deploy',
            createdAt: '',
          ),
        ]);
        await second;
        repo.calls[0].complete([
          const ChatMessage(
            id: 'scoped',
            conversationId: 'a',
            userId: 'u',
            body: 'deploy',
            createdAt: '',
          ),
        ]);
        await first;
        expect(container.read(chatProvider).searchResults.map((m) => m.id), [
          'global',
        ]);
        expect(container.read(chatProvider).searchIdentity, (
          query: 'deploy',
          conversationId: null,
        ));
      } finally {
        container.dispose();
        await db.close();
      }
    },
  );

  test('rapid input only starts the final server search', () async {
    final db = ChatLocalDb.forTesting(NativeDatabase.memory());
    final repo = _Repo();
    final container = ProviderContainer(
      overrides: [
        chatProvider.overrideWith(() => _Chat(ChatMessageStore(db), repo)),
        messageVaultProvider.overrideWithValue(MessageVault(repo, _storage)),
      ],
    );
    try {
      final chat = container.read(chatProvider.notifier);
      final first = chat.searchMessages('dep');
      final second = chat.searchMessages('deploy');
      await first;
      while (repo.calls.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(repo.calls, hasLength(1));
      repo.calls.single.complete([]);
      await second;
      final clearing = chat.searchMessages('');
      await clearing;
      expect(container.read(chatProvider).searchLoading, isFalse);
      expect(container.read(chatProvider).searchResults, isEmpty);
      expect(repo.calls, hasLength(1));
    } finally {
      container.dispose();
      await db.close();
    }
  });

  testWidgets('same text starts a new search for each scope', (tester) async {
    final chat = _RecordingChat();
    final container = ProviderContainer(
      overrides: [...noTypingOverrides, chatProvider.overrideWith(() => chat)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: Column(
                children: [
                  for (final scope in <String?>['a', null, 'b'])
                    TextButton(
                      onPressed: () =>
                          openChatSearch(context, ref, conversationId: scope),
                      child: Text(scope ?? 'global'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    for (final scope in <String?>['a', null, 'b', 'a']) {
      await tester.tap(find.text(scope ?? 'global'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'deploy');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
    }
    expect(chat.scopes, ['a', null, 'b', 'a']);
  });
}
