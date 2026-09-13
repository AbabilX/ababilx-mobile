import 'dart:async';

import 'package:ababilx/core/router/shell_bottom_bar/shell_chrome_provider.dart';
import 'package:ababilx/features/messages/chat-list/chat_search.dart';
import 'package:ababilx/features/messages/data/models/chat_models.dart';
import 'package:ababilx/features/messages/providers/chat_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _DelayedSearchNotifier extends ChatNotifier {
  final ready = Completer<void>();

  @override
  ChatState build() => const ChatState();

  @override
  Future<void> searchMessages(String query) async {
    state = state.copyWith(searchLoading: true);
    await ready.future;
    state = state.copyWith(
      searchLoading: false,
      searchResults: [
        ChatMessage(
          id: 'message-1',
          conversationId: 'conversation-1',
          userId: 'user-1',
          body: 'local deploy result',
          createdAt: '2026-08-25T00:00:00Z',
        ),
      ],
    );
  }
}

class _ChatsThenMessagesNotifier extends ChatNotifier {
  @override
  ChatState build() => ChatState(
    dms: [
      ChatConversation(
        id: 'junayed-dm',
        teamId: '',
        scope: 'personal',
        type: 'dm',
        createdAt: '2026-09-01T00:00:00Z',
        lastMessageAt: '2026-09-07T00:00:00Z',
        peerUserId: 'junayed',
        peerUserName: 'Junayed',
      ),
    ],
  );

  @override
  Future<void> searchMessages(String query) async {
    state = state.copyWith(
      searchLoading: false,
      searchResults: [
        ChatMessage(
          id: 'message-1',
          conversationId: 'other-dm',
          userId: 'alice',
          userName: 'Alice',
          body: 'Jun was here yesterday',
          createdAt: '2026-09-01T00:00:00Z',
        ),
      ],
    );
  }
}

Future<void> _openSearch(
  WidgetTester tester,
  ProviderContainer container,
) async {
  late WidgetRef ref;
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Consumer(
          builder: (context, widgetRef, _) {
            ref = widgetRef;
            return Scaffold(
              body: ElevatedButton(
                onPressed: () => openChatSearch(context, ref),
                child: const Text('Search'),
              ),
            );
          },
        ),
      ),
    ),
  );
  await tester.tap(find.text('Search'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('chat search redraws when local results arrive', (tester) async {
    final container = ProviderContainer(
      overrides: [chatProvider.overrideWith(_DelayedSearchNotifier.new)],
    );
    addTearDown(container.dispose);

    await _openSearch(tester, container);
    await tester.enterText(find.byType(TextField), 'deploy');
    await tester.pump();
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    final notifier =
        container.read(chatProvider.notifier) as _DelayedSearchNotifier;
    notifier.ready.complete();
    await tester.pumpAndSettle();

    expect(find.text('local deploy result'), findsOneWidget);
    expect(find.text('Messages'), findsOneWidget);
  });

  testWidgets('name-matched chats render above message hits', (tester) async {
    final container = ProviderContainer(
      overrides: [chatProvider.overrideWith(_ChatsThenMessagesNotifier.new)],
    );
    addTearDown(container.dispose);

    await _openSearch(tester, container);
    await tester.enterText(find.byType(TextField), 'Jun');
    await tester.pumpAndSettle();

    expect(find.text('Chats'), findsOneWidget);
    expect(find.text('Junayed'), findsOneWidget);
    expect(find.text('Messages'), findsOneWidget);
    expect(find.text('Jun was here yesterday'), findsOneWidget);

    final chatsHeader = tester.getTopLeft(find.text('Chats'));
    final junayed = tester.getTopLeft(find.text('Junayed'));
    final messagesHeader = tester.getTopLeft(find.text('Messages'));
    final messageHit = tester.getTopLeft(find.text('Jun was here yesterday'));
    expect(chatsHeader.dy, lessThan(junayed.dy));
    expect(junayed.dy, lessThan(messagesHeader.dy));
    expect(messagesHeader.dy, lessThan(messageHit.dy));
  });

  testWidgets('chat search hides the shell bottom bar until it closes', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [chatProvider.overrideWith(_ChatsThenMessagesNotifier.new)],
    );
    addTearDown(container.dispose);

    await _openSearch(tester, container);
    expect(container.read(shellBottomBarHiddenProvider), isTrue);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(container.read(shellBottomBarHiddenProvider), isFalse);
  });
}
