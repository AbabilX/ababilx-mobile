import 'package:ababilx/features/messages/chat-details/avatar_preview.dart';
import 'package:ababilx/features/messages/chat-details/conversation_details_screen.dart';
import 'package:ababilx/features/messages/data/models/chat_models.dart';
import 'package:ababilx/features/messages/providers/chat_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'no_pins_override.dart';

ChatConversation _group({String? avatarUrl, String? bannerUrl}) =>
    ChatConversation(
      id: 'g1',
      teamId: '',
      scope: 'personal',
      type: 'group',
      name: 'Full Team',
      createdAt: '2026-09-01T10:00:00Z',
      myRole: 'admin',
      memberCount: 2,
      avatarUrl: avatarUrl,
      bannerUrl: bannerUrl,
    );

class _Notifier extends ChatNotifier {
  _Notifier(this._groupConv, this._members);

  final ChatConversation _groupConv;
  final List<ChatMember> _members;

  @override
  ChatState build() => ChatState(currentUserId: 'me', channels: [_groupConv]);

  @override
  Future<List<ChatMember>> listChannelMembers(String channelId) async =>
      _members;
}

void main() {
  test('previewPhotoUrl ignores a blank or letter-only avatar', () {
    expect(previewPhotoUrl(null), isNull);
    expect(previewPhotoUrl(''), isNull);
    expect(previewPhotoUrl('   '), isNull);
  });

  test('previewPhotoUrl keeps a CDN photo and enlarges a Google crop', () {
    expect(
      previewPhotoUrl('https://cdn.example/group.jpg'),
      'https://cdn.example/group.jpg',
    );
    expect(
      previewPhotoUrl('https://lh3.googleusercontent.com/a/abc=s128-c'),
      'https://lh3.googleusercontent.com/a/abc=s720-c',
    );
  });

  testWidgets('tapping the group photo opens the fullscreen viewer', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          noPinsOverride,
          chatProvider.overrideWith(
            () => _Notifier(_group(avatarUrl: 'https://cdn.example/g.jpg'), [
              const ChatMember(
                userId: 'me',
                name: 'Me',
                joinedAt: '2026-09-01T10:00:00Z',
                role: 'admin',
              ),
            ]),
          ),
        ],
        child: const MaterialApp(
          home: ConversationDetailsScreen(conversationId: 'g1'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.byKey(const ValueKey('header-avatar-preview')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byTooltip('Close'), findsOneWidget);
    expect(find.text('Full Team.jpg'), findsOneWidget);
  });

  testWidgets('a letter-only header does not open a viewer', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          noPinsOverride,
          chatProvider.overrideWith(
            () => _Notifier(_group(), const [
              ChatMember(
                userId: 'me',
                name: 'Me',
                joinedAt: '2026-09-01T10:00:00Z',
                role: 'admin',
              ),
            ]),
          ),
        ],
        child: const MaterialApp(
          home: ConversationDetailsScreen(conversationId: 'g1'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const ValueKey('header-avatar-preview')), findsNothing);
    expect(find.byTooltip('Close'), findsNothing);
  });

  testWidgets('tapping a member photo opens the viewer, not the sheet', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          noPinsOverride,
          chatProvider.overrideWith(
            () => _Notifier(_group(), const [
              ChatMember(
                userId: 'me',
                name: 'Me',
                joinedAt: '2026-09-01T10:00:00Z',
                role: 'admin',
              ),
              ChatMember(
                userId: 'u2',
                name: 'Badhon',
                avatarUrl: 'https://cdn.example/badhon.jpg',
                joinedAt: '2026-09-01T10:00:00Z',
              ),
            ]),
          ),
        ],
        child: const MaterialApp(
          home: ConversationDetailsScreen(conversationId: 'g1'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.scrollUntilVisible(find.text('Badhon'), 200);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('member-avatar-preview-u2')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byTooltip('Close'), findsOneWidget);
    expect(find.text('View profile'), findsNothing);
    expect(find.text('Badhon.jpg'), findsOneWidget);
  });
}
