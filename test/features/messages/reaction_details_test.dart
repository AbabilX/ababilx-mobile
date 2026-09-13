import 'package:ababilx/features/messages/chat-timeline/reaction_details.dart';
import 'package:ababilx/features/messages/chat_utils.dart';
import 'package:ababilx/features/messages/data/models/chat_models.dart';
import 'package:ababilx/features/messages/providers/chat_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final thumbs = ChatReactionGroup(
    emoji: '👍',
    count: 2,
    users: const [
      ChatReactionUser(userId: 'a', name: 'Ada'),
      ChatReactionUser(userId: 'b', name: 'Bob'),
    ],
  );
  final hearts = ChatReactionGroup(
    emoji: '❤️',
    count: 1,
    users: const [ChatReactionUser(userId: 'a', name: 'Ada')],
  );

  test('reads server user_name onto the person', () {
    final user = ChatReactionUser.fromJson({
      'user_id': 'u1',
      'user_name': 'Ada',
      'avatar_url': 'https://cdn.example/ada.jpg',
    });
    expect(user.userId, 'u1');
    expect(user.name, 'Ada');
    expect(user.avatarUrl, 'https://cdn.example/ada.jpg');
  });

  test('reactor avatar prefers the reaction payload, then the feed', () {
    expect(
      reactorAvatarUrl(
        userId: 'a',
        fromReaction: 'https://cdn.example/react.jpg',
        known: const {'a': 'https://cdn.example/feed.jpg'},
      ),
      'https://cdn.example/react.jpg',
    );
    const msg = ChatMessage(
      id: 'm1',
      conversationId: 'c1',
      userId: 'a',
      userAvatarUrl: 'https://cdn.example/feed.jpg',
      body: 'hi',
      createdAt: '2026-09-14T10:00:00Z',
    );
    final known = reactorAvatarIndex(
      ChatState(
        feeds: {
          feedKey('c1'): const ChatFeed(messages: [msg]),
        },
      ),
    );
    expect(
      reactorAvatarUrl(userId: 'a', known: known),
      'https://cdn.example/feed.jpg',
    );
    expect(reactorAvatarUrl(userId: 'missing', known: known), isNull);
  });

  test('one emoji has no All tab', () {
    final tabs = buildReactionDetailTabs([thumbs]);
    expect(tabs, hasLength(1));
    expect(tabs.single.emoji, '👍');
    expect(tabs.single.count, 2);
  });

  test('several emojis open with All then each emoji', () {
    final tabs = buildReactionDetailTabs([thumbs, hearts]);
    expect(tabs.map((t) => t.emoji).toList(), [null, '👍', '❤️']);
    expect(tabs.first.count, 3);
    expect(reactionDetailsInitialTab(tabs: tabs, initialEmoji: '❤️'), 2);
  });

  test('All lists every reactor; an emoji tab filters', () {
    final tabs = buildReactionDetailTabs([thumbs, hearts]);
    expect(
      reactionDetailRows(groups: [thumbs, hearts], tab: tabs.first),
      hasLength(3),
    );
    expect(
      reactionDetailRows(
        groups: [thumbs, hearts],
        tab: tabs[2],
      ).map((r) => r.userId).toList(),
      ['a'],
    );
  });

  test('finds a message in the active feed or a thread', () {
    const msg = ChatMessage(
      id: 'm1',
      conversationId: 'c1',
      userId: 'u',
      body: 'hi',
      createdAt: '2026-09-14T10:00:00Z',
    );
    final chat = ChatState(
      feeds: {
        feedKey('c1'): const ChatFeed(messages: [msg]),
      },
    );
    expect(findChatMessage(chat, 'm1')?.id, 'm1');
    expect(findChatMessage(chat, 'missing'), isNull);
  });
}
