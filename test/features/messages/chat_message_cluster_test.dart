import 'package:ababilx/features/messages/chat_utils.dart';
import 'package:ababilx/features/messages/chat-timeline/message_bubble.dart';
import 'package:ababilx/features/messages/chat-timeline/message_list.dart';
import 'package:ababilx/features/messages/data/models/chat_models.dart';
import 'package:ababilx/features/messages/providers/chat_provider.dart';
import 'package:ababilx/shared/widgets/app_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A group, so the layout shows what only a group shows: the sender's name
/// over the first bubble of a run and their avatar under the last. A DM draws
/// neither.
class _ClusterChatNotifier extends ChatNotifier {
  @override
  ChatState build() => ChatState(
    currentUserId: 'me',
    channels: const [
      ChatConversation(
        id: 'conversation-1',
        teamId: 'team-1',
        createdAt: '2026-08-29T06:00:00Z',
        type: 'channel',
        name: 'general',
      ),
    ],
  );
}

ChatMessage _message({
  required String id,
  required String userId,
  required String createdAt,
  String conversationId = 'conversation-1',
  String? parentId,
  String messageType = 'text',
  String? userName,
}) => ChatMessage(
  id: id,
  conversationId: conversationId,
  userId: userId,
  body: id,
  parentId: parentId,
  createdAt: createdAt,
  messageType: messageType,
  userName: userName,
);

void main() {
  group('chatMessageClusterPosition', () {
    test('marks a same-sender clock-minute run as start, middle, end', () {
      final messages = [
        _message(id: '1', userId: 'alice', createdAt: '2026-08-29T06:10:01Z'),
        _message(id: '2', userId: 'alice', createdAt: '2026-08-29T06:10:30Z'),
        _message(id: '3', userId: 'alice', createdAt: '2026-08-29T06:10:59Z'),
      ];

      expect(
        chatMessageClusterPosition(null, messages[0], messages[1]),
        MessageClusterPosition.start,
      );
      expect(
        chatMessageClusterPosition(messages[0], messages[1], messages[2]),
        MessageClusterPosition.middle,
      );
      expect(
        chatMessageClusterPosition(messages[1], messages[2], null),
        MessageClusterPosition.end,
      );
    });

    test('starts a new cluster at the next clock minute', () {
      final previous = _message(
        id: '1',
        userId: 'alice',
        createdAt: '2026-08-29T06:10:59Z',
      );
      final current = _message(
        id: '2',
        userId: 'alice',
        createdAt: '2026-08-29T06:11:00Z',
      );

      expect(
        chatMessageClusterPosition(previous, current, null),
        MessageClusterPosition.single,
      );
    });

    test('sender, thread, and special-message boundaries split clusters', () {
      final current = _message(
        id: '2',
        userId: 'alice',
        createdAt: '2026-08-29T06:10:20Z',
      );
      final differentSender = _message(
        id: '1',
        userId: 'bob',
        createdAt: '2026-08-29T06:10:10Z',
      );
      final differentThread = _message(
        id: '3',
        userId: 'alice',
        createdAt: '2026-08-29T06:10:30Z',
        parentId: 'thread-1',
      );
      final systemMessage = _message(
        id: '4',
        userId: 'alice',
        createdAt: '2026-08-29T06:10:40Z',
        messageType: 'system',
      );

      expect(
        chatMessageClusterPosition(differentSender, current, differentThread),
        MessageClusterPosition.single,
      );
      expect(
        chatMessageClusterPosition(null, systemMessage, null),
        MessageClusterPosition.single,
      );
    });
  });

  testWidgets('one run of messages shows one name and one avatar', (
    tester,
  ) async {
    final messages = [
      _message(
        id: 'one',
        userId: 'alice',
        createdAt: '2026-08-29T06:10:01Z',
        userName: 'Alice',
      ),
      _message(
        id: 'two',
        userId: 'alice',
        createdAt: '2026-08-29T06:10:30Z',
        userName: 'Alice',
      ),
      _message(
        id: 'three',
        userId: 'alice',
        createdAt: '2026-08-29T06:10:59Z',
        userName: 'Alice',
      ),
    ];
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [chatProvider.overrideWith(_ClusterChatNotifier.new)],
        child: MaterialApp(
          home: Scaffold(
            body: MessageList(
              messages: messages,
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

    expect(find.text('Alice'), findsOneWidget);
    expect(find.byType(AppAvatar), findsOneWidget);
    expect(find.text(formatChatTime(messages.last.createdAt)), findsOneWidget);
    expect(find.text('one'), findsOneWidget);
    expect(find.text('two'), findsOneWidget);
    expect(find.text('three'), findsOneWidget);
  });

  // Signal hangs the avatar off the *bottom* of a run — the opposite of the
  // Slack layout this replaced, where it sat beside the sender name on top.
  testWidgets('avatar sits at the foot of the bubble, not beside the name', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [chatProvider.overrideWith(_ClusterChatNotifier.new)],
        child: MaterialApp(
          home: Scaffold(
            body: MessageList(
              messages: [
                ChatMessage(
                  id: 'm1',
                  conversationId: 'conversation-1',
                  userId: 'alice',
                  userName: 'Alice',
                  body: 'hi\nHey',
                  createdAt: '2026-08-29T06:10:00Z',
                ),
              ],
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

    final avatar = tester.getRect(find.byType(AppAvatar));
    final name = tester.getRect(find.text('Alice'));
    final bubble = tester.getRect(find.byType(MessageBubble));

    expect(avatar.top, greaterThan(name.bottom));
    expect(avatar.bottom, closeTo(bubble.bottom, 2));
    // And it is on the left of the bubble, because the message is incoming.
    expect(avatar.right, lessThanOrEqualTo(bubble.left));
  });

  testWidgets('an outgoing bubble is right-aligned and carries no avatar', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [chatProvider.overrideWith(_ClusterChatNotifier.new)],
        child: MaterialApp(
          home: Scaffold(
            body: MessageList(
              messages: [
                _message(
                  id: 'mine',
                  userId: 'me',
                  createdAt: '2026-08-29T06:10:00Z',
                  userName: 'Me',
                ),
              ],
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

    expect(find.byType(AppAvatar), findsNothing);
    expect(find.text('Me'), findsNothing);

    final bubble = tester.getRect(find.byType(MessageBubble));
    final screen = tester.getRect(find.byType(MessageList));
    expect(bubble.right, closeTo(screen.right - 16, 1));
    expect(bubble.left, greaterThan(screen.center.dx));
  });
}
