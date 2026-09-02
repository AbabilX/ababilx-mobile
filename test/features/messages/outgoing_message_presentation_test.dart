import 'package:ababilx/features/messages/chat-timeline/message_list.dart';
import 'package:ababilx/features/messages/data/models/chat_models.dart';
import 'package:ababilx/features/messages/providers/chat_provider.dart';
import 'package:ababilx/features/messages/chat-timeline/timeline_reveal_policy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _ChatNotifier extends ChatNotifier {
  @override
  ChatState build() => const ChatState(currentUserId: 'me');
}

ChatMessage _message(String id, String userId) => ChatMessage(
  id: id,
  conversationId: 'conversation-1',
  userId: userId,
  userName: userId,
  body: id,
  createdAt: '2026-09-03T10:00:00Z',
);

void main() {
  testWidgets('only an outgoing message shows its tick at the right edge', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [chatProvider.overrideWith(_ChatNotifier.new)],
        child: MaterialApp(
          home: Scaffold(
            body: MessageList(
              messages: [_message('mine', 'me'), _message('theirs', 'peer')],
              loading: false,
              loadingMore: false,
              currentUserId: 'me',
              scrollController: controller,
              conversationId: 'conversation-1',
            ),
          ),
        ),
      ),
    );

    final ticks = find.byIcon(Icons.done_rounded);
    expect(ticks, findsOneWidget);
    expect(tester.getCenter(ticks).dx, greaterThan(400));
  });

  test('a newly inserted outgoing message always requests bottom reveal', () {
    final messages = [_message('old', 'peer'), _message('new', 'me')];

    expect(
      shouldRevealNewestMessage(
        previousNewestId: 'old',
        messages: messages,
        currentUserId: 'me',
        isNearBottom: false,
      ),
      isTrue,
    );
  });

  test('an incoming message only requests reveal near the bottom', () {
    final messages = [_message('old', 'me'), _message('new', 'peer')];

    expect(
      shouldRevealNewestMessage(
        previousNewestId: 'old',
        messages: messages,
        currentUserId: 'me',
        isNearBottom: false,
      ),
      isFalse,
    );
  });
}
