import 'package:ababilx/features/messages/chat-select/message_selection.dart';
import 'package:ababilx/features/messages/chat-select/selection_bottom_bar.dart';
import 'package:ababilx/features/messages/chat-select/selection_top_bar.dart';
import 'package:ababilx/features/messages/chat-timeline/message_list.dart';
import 'package:ababilx/features/messages/data/models/chat_models.dart';
import 'package:ababilx/features/messages/providers/chat_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'no_pins_override.dart';
import 'no_typing_override.dart';

const _conversationId = 'c1';

ChatMessage _message(String id, {String userId = 'me', String? createdAt}) =>
    ChatMessage(
      id: id,
      conversationId: _conversationId,
      userId: userId,
      body: id,
      createdAt: createdAt ?? '2026-09-12T06:1${id.length}:00Z',
    );

/// One incoming, one outgoing — the pair the rules and the layout both turn
/// on: only an incoming row shifts for the gutter, and only an outgoing one
/// may be edited or deleted.
final _messages = [
  _message('one', userId: 'alice'),
  _message('two', createdAt: '2026-09-12T06:20:00Z'),
];

class _SelectChatNotifier extends ChatNotifier {
  @override
  ChatState build() => ChatState(
    currentUserId: 'me',
    dms: const [
      ChatConversation(
        id: _conversationId,
        teamId: '',
        createdAt: '2026-09-12T06:00:00Z',
        type: 'dm',
        name: 'Alice',
        peerUserId: 'alice',
      ),
    ],
    feeds: {_conversationId: ChatFeed(messages: _messages)},
  );
}

Widget _app(Widget child) => ProviderScope(
  overrides: [
    ...noTypingOverrides,
    noPinsOverride,
    noGroupPinsOverride,
    chatProvider.overrideWith(_SelectChatNotifier.new),
  ],
  child: MaterialApp(home: Scaffold(body: child)),
);

Widget _list(ScrollController controller) => MessageList(
  messages: _messages,
  loading: false,
  loadingMore: false,
  currentUserId: 'me',
  scrollController: controller,
  conversationId: _conversationId,
);

void main() {
  Future<WidgetRef> mount(WidgetTester tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    late WidgetRef ref;
    await tester.pumpWidget(
      _app(
        Consumer(
          builder: (context, r, _) {
            ref = r;
            return _list(controller);
          },
        ),
      ),
    );
    return ref;
  }

  testWidgets('a hold opens the menu, and its Select opens multi-select', (
    tester,
  ) async {
    final ref = await mount(tester);

    await tester.longPress(find.text('one'));
    // A row runs a repeating pulse animation, so the tree never settles; pump
    // the frames the route needs instead.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Select'), findsOneWidget);
    expect(ref.read(messageSelectionProvider).isActive, isFalse);

    await tester.tap(find.text('Select'));
    await tester.pump(const Duration(milliseconds: 400));

    final selection = ref.read(messageSelectionProvider);
    expect(selection.isActiveIn(_conversationId), isTrue);
    expect(selection.ids, {'one'});

    // In the mode a hold picks rows, as a tap does.
    await tester.longPress(find.text('two'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(ref.read(messageSelectionProvider).ids, {'one', 'two'});
  });

  testWidgets('a plain tap opens nothing', (tester) async {
    final ref = await mount(tester);

    await tester.tap(find.text('one'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Select'), findsNothing);
    expect(ref.read(messageSelectionProvider).isActive, isFalse);
  });

  testWidgets('a double tap copies the text, no menu', (tester) async {
    await mount(tester);
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.tap(find.text('one'));
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tap(find.text('one'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Select'), findsNothing);
    expect(copied, 'one');
    // Let the "copied" SnackBar's timer run out before the test ends.
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a selected row is checked, and the rest shift over for it', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final container = ProviderContainer(
      overrides: [
        ...noTypingOverrides,
        noPinsOverride,
        noGroupPinsOverride,
        chatProvider.overrideWith(_SelectChatNotifier.new),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: Scaffold(body: _list(controller))),
      ),
    );
    final restingLeft = tester.getRect(find.text('one')).left;
    final outgoingRight = tester.getRect(find.text('two')).right;

    container
        .read(messageSelectionProvider.notifier)
        .start(conversationId: _conversationId, messageId: 'one');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // The reference app's gutter: an incoming row moves from 16 to 48. An
    // outgoing one does not move at all — `getHorizontalTranslationTarget`
    // returns null for it, and a right-aligned bubble has nowhere to go.
    expect(tester.getRect(find.text('one')).left - restingLeft, closeTo(32, 1));
    expect(tester.getRect(find.text('two')).right, closeTo(outgoingRight, 1));
    expect(find.byIcon(Icons.check_circle), findsOneWidget);

    // A tap now picks rows instead of opening anything.
    await tester.tap(find.text('two'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(container.read(messageSelectionProvider).ids, {'one', 'two'});
    expect(find.byIcon(Icons.check_circle), findsNWidgets(2));

    // The typing provider's periodic timer has to stop before the test ends.
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });

  testWidgets('the bars replace the header and the composer', (tester) async {
    final container = ProviderContainer(
      overrides: [
        ...noTypingOverrides,
        noPinsOverride,
        noGroupPinsOverride,
        chatProvider.overrideWith(_SelectChatNotifier.new),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(messageSelectionProvider.notifier)
        .start(conversationId: _conversationId, messageId: 'two');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Column(
              children: const [
                SelectionTopBar(conversationId: _conversationId),
                SelectionBottomBar(conversationId: _conversationId),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('1 selected'), findsOneWidget);
    // One of your own messages: Reply and Forward as labelled capsules at
    // the bottom, the rest as icons in the top capsule.
    expect(find.text('Reply'), findsOneWidget);
    expect(find.text('Forward'), findsOneWidget);
    expect(find.byTooltip('Forward'), findsNothing);
    expect(find.byTooltip('Copy'), findsOneWidget);
    expect(find.byTooltip('Edit'), findsOneWidget);
    expect(find.byTooltip('Delete'), findsOneWidget);

    container
        .read(messageSelectionProvider.notifier)
        .toggle(conversationId: _conversationId, messageId: 'one');
    await tester.pump();
    // Reply drains away as Forward takes the full width.
    await tester.pump(const Duration(milliseconds: 500));

    // Two messages: the reference app drops everything that only means anything
    // against one of them. Delete stays: an incoming message can still be
    // deleted for me, the dialog just withholds "for everyone".
    expect(find.text('2 selected'), findsOneWidget);
    expect(find.text('Reply'), findsNothing);
    expect(find.byTooltip('Edit'), findsNothing);
    expect(find.text('Forward'), findsOneWidget);
    expect(find.byTooltip('Copy'), findsOneWidget);
    expect(find.byTooltip('Delete'), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pump();
    expect(container.read(messageSelectionProvider).isActive, isFalse);
  });
}
