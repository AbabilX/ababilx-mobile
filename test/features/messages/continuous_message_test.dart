import 'dart:async';

import 'package:ababilx/features/messages/chat-timeline/chat_timeline.dart';
import 'package:ababilx/features/messages/chat-timeline/composer.dart';
import 'package:ababilx/features/messages/chat-timeline/composer_input_bar.dart';
import 'package:ababilx/features/messages/chat-timeline/composer_input_bar_buttons.dart';
import 'package:ababilx/features/messages/chat_utils.dart';
import 'package:ababilx/features/messages/data/models/chat_models.dart';
import 'package:ababilx/features/messages/data/local/composer_draft_store.dart';
import 'package:ababilx/features/messages/providers/chat_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  Future<List<ChatMember>> listChannelMembers(String channelId) async => [];

  @override
  Future<ChatMessage?> sendMessage({
    String? conversationId,
    required String body,
    List<ChatAttachmentInput> attachments = const [],
    List<String> mentionedUserIds = const [],
    String? parentId,
    String? quotedMessageId,
    ChatMessageQuote? quotePreview,
    String? clientMessageId,
    bool reusePending = false,
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
  Future<bool> hydrateFeedFromCache(
    String conversationId, {
    String? threadRootId,
  }) async => false;

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
    String? quotedMessageId,
    ChatMessageQuote? quotePreview,
    String? clientMessageId,
    bool reusePending = false,
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

class _FailingComposerNotifier extends _ComposerNotifier {
  @override
  Future<ChatMessage?> sendMessage({
    String? conversationId,
    required String body,
    List<ChatAttachmentInput> attachments = const [],
    List<String> mentionedUserIds = const [],
    String? parentId,
    String? quotedMessageId,
    ChatMessageQuote? quotePreview,
    String? clientMessageId,
    bool reusePending = false,
  }) async => null;
}

final _sendResultProvider = Provider<Completer<ChatMessage?>>(
  (ref) => Completer<ChatMessage?>(),
);

class _CompletingComposerNotifier extends _ComposerNotifier {
  @override
  Future<ChatMessage?> sendMessage({
    String? conversationId,
    required String body,
    List<ChatAttachmentInput> attachments = const [],
    List<String> mentionedUserIds = const [],
    String? parentId,
    String? quotedMessageId,
    ChatMessageQuote? quotePreview,
    String? clientMessageId,
    bool reusePending = false,
  }) => ref.read(_sendResultProvider).future;
}

class _DelayedDraftStore extends ComposerDraftStore {
  final readGate = Completer<void>();
  final List<String> writes = [];

  @override
  Future<String> read(
    String ownerId,
    String conversationId, {
    String? parentId,
  }) async {
    await readGate.future;
    return 'stored draft';
  }

  @override
  Future<void> write(
    String ownerId,
    String conversationId,
    String text, {
    String? parentId,
  }) async {
    writes.add(text);
    await super.write(ownerId, conversationId, text, parentId: parentId);
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
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('an unsent draft survives composer disposal and recreation', (
    tester,
  ) async {
    Widget composer() => ProviderScope(
      overrides: [chatProvider.overrideWith(_ComposerNotifier.new)],
      child: const MaterialApp(
        home: Scaffold(body: MessageComposer(conversationId: 'conversation-1')),
      ),
    );

    await tester.pumpWidget(composer());
    await tester.enterText(find.byType(TextField), 'keep this draft');
    await tester.pump();

    // Models Activity/FlutterEngine recreation after Home or another app.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(composer());
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller?.text, 'keep this draft');
  });

  testWidgets('draft storage clears on success and survives a failed send', (
    tester,
  ) async {
    Future<void> mount(ChatNotifier Function() notifier) => tester.pumpWidget(
      ProviderScope(
        overrides: [chatProvider.overrideWith(notifier)],
        child: const MaterialApp(
          home: Scaffold(
            body: MessageComposer(conversationId: 'conversation-1'),
          ),
        ),
      ),
    );

    await mount(_ComposerNotifier.new);
    await _typeAndSend(tester, 'delivered');
    await tester.pumpAndSettle();
    expect(await ComposerDraftStore().read('me', 'conversation-1'), isEmpty);

    await tester.pumpWidget(const SizedBox());
    await mount(_FailingComposerNotifier.new);
    await _typeAndSend(tester, 'retry me');
    await tester.pumpAndSettle();
    expect(await ComposerDraftStore().read('me', 'conversation-1'), 'retry me');
  });

  testWidgets('dispose during restore never erases the stored draft', (
    tester,
  ) async {
    final store = _DelayedDraftStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatProvider.overrideWith(_ComposerNotifier.new),
          composerDraftStoreProvider.overrideWithValue(store),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: MessageComposer(conversationId: 'conversation-1'),
          ),
        ),
      ),
    );

    await tester.pumpWidget(const SizedBox());
    expect(store.writes, isEmpty);
    store.readGate.complete();
    await tester.pump();
  });

  testWidgets('typing before restore completes is persisted on dispose', (
    tester,
  ) async {
    final store = _DelayedDraftStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatProvider.overrideWith(_ComposerNotifier.new),
          composerDraftStoreProvider.overrideWithValue(store),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: MessageComposer(conversationId: 'conversation-1'),
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'newer draft');
    await tester.pumpWidget(const SizedBox());

    expect(store.writes, ['newer draft']);
    store.readGate.complete();
    await tester.pump();
  });

  testWidgets('a successful send clears its draft after widget disposal', (
    tester,
  ) async {
    final store = _DelayedDraftStore()..readGate.complete();
    final result = Completer<ChatMessage?>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatProvider.overrideWith(_CompletingComposerNotifier.new),
          composerDraftStoreProvider.overrideWithValue(store),
          _sendResultProvider.overrideWithValue(result),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: MessageComposer(conversationId: 'conversation-1'),
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'send me');
    await tester.tap(find.byType(AccentCircle));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());

    result.complete(_message('sent-after-dispose', 'me'));
    await tester.pump();

    expect(await ComposerDraftStore().read('me', 'conversation-1'), isEmpty);
  });

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
