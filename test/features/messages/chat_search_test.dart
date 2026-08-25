import 'dart:async';

import 'package:ababilx/features/messages/chat-list/chat_search.dart';
import 'package:ababilx/features/messages/data/models/chat_message.dart';
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
    await ready.future;
    state = state.copyWith(
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

void main() {
  testWidgets('chat search redraws when local results arrive', (tester) async {
    late WidgetRef ref;
    final container = ProviderContainer(
      overrides: [chatProvider.overrideWith(_DelayedSearchNotifier.new)],
    );
    addTearDown(container.dispose);

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
    await tester.enterText(find.byType(TextField), 'deploy');
    await tester.pump();

    final notifier =
        container.read(chatProvider.notifier) as _DelayedSearchNotifier;
    notifier.ready.complete();
    await tester.pumpAndSettle();

    expect(find.text('local deploy result'), findsOneWidget);
  });
}
