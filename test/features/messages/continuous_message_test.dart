import 'package:ababilx/features/messages/chat-timeline/chat_timeline.dart';
import 'package:ababilx/features/messages/chat-timeline/composer.dart';
import 'package:ababilx/features/messages/chat-timeline/composer_input_bar.dart';
import 'package:ababilx/features/messages/chat-timeline/composer_input_bar_buttons.dart';
import 'package:ababilx/features/messages/chat_utils.dart';
import 'package:ababilx/features/messages/data/models/chat_models.dart';
import 'package:ababilx/features/messages/providers/chat_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ChatMessage _message(String id, String userId, {String? body}) => ChatMessage(
  id: id,
  conversationId: 'conversation-1',
  userId: userId,
  userName: userId,
  body: body ?? id,
  createdAt: '2026-09-03T10:00:00Z',
);

class _ComposerNotifier extends ChatNotifier {
  @override
  ChatState build() => const ChatState(currentUserId: 'me');

  @override
  Future<ChatMessage?> sendMessage({
    String? conversationId,
    required String body,
    List<ChatAttachmentInput> attachments = const [],
    List<String> mentionedUserIds = const [],
    String? parentId,
    String? clientMessageId,
  }) async => _message('sent', 'me', body: body);
}

class _TimelineNotifier extends _ComposerNotifier {
  @override
  ChatState build() => ChatState(
    currentUserId: 'me',
    // A route can render while the shared active id is still transitioning
    // (for example after opening from a notification). The composer must use
    // its own displayed conversation id, never this stale global value.
    activeConversationId: 'another-conversation',
    feeds: {
      feedKey('conversation-1'): ChatFeed(
        messages: List.generate(
          25,
          (i) => _message('history-$i', i.isEven ? 'me' : 'peer'),
        ),
      ),
    },
  );

  @override
  Future<bool> hydrateFeedFromCache(String conversationId) async => false;

  @override
  Future<void> loadFeed(
    String conversationId, {
    String? threadRootId,
    bool force = false,
  }) async {}

  @override
  Future<void> markConversationRead(String conversationId) async {}

  @override
  Future<ChatMessage?> sendMessage({
    String? conversationId,
    required String body,
    List<ChatAttachmentInput> attachments = const [],
    List<String> mentionedUserIds = const [],
    String? parentId,
    String? clientMessageId,
  }) async {
    final id = conversationId ?? state.activeConversationId!;
    final key = feedKey(id, threadRootId: parentId);
    final feed = state.feeds[key] ?? const ChatFeed();
    final message = _message('continuous-message', 'me', body: body);
    state = state.copyWith(
      feeds: {
        ...state.feeds,
        key: feed.copyWith(messages: [...feed.messages, message]),
      },
    );
    return message;
  }
}

Future<void> _typeAndSend(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump();
  // The one circle beside the pill: "+" until there is a draft, send after.
  await tester.tap(find.byType(AccentCircle));
  await tester.pump();
}

void main() {
  testWidgets('sending keeps focus and requests newest-message reveal', (
    tester,
  ) async {
    var revealRequested = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [chatProvider.overrideWith(_ComposerNotifier.new)],
        child: MaterialApp(
          home: Scaffold(
            body: MessageComposer(
              conversationId: 'conversation-1',
              onMessageSubmitted: () => revealRequested = true,
            ),
          ),
        ),
      ),
    );
    await _typeAndSend(tester, 'keep typing');
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.focusNode?.hasFocus, isTrue);
    expect(field.controller?.text, isEmpty);
    expect(revealRequested, isTrue);

    await tester.enterText(find.byType(TextField), 'second message');
    await tester.pump();
    await tester.tap(find.byType(AccentCircle));
    await tester.pumpAndSettle();
    final continuedField = tester.widget<TextField>(find.byType(TextField));
    expect(continuedField.focusNode?.hasFocus, isTrue);
    expect(continuedField.controller?.text, isEmpty);
  });

  testWidgets('sent message remains visible above the focused composer', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [chatProvider.overrideWith(_TimelineNotifier.new)],
        child: const MaterialApp(
          home: Scaffold(body: ChatTimeline(conversationId: 'conversation-1')),
        ),
      ),
    );
    await tester.pump();
    await _typeAndSend(tester, 'continuous message');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();

    final message = find.text('continuous message');
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(message, findsOneWidget);
    expect(field.focusNode?.hasFocus, isTrue);
    expect(
      tester.getBottomLeft(message).dy,
      lessThan(tester.getTopLeft(find.byType(ComposerInputBar)).dy),
    );
  });
}
