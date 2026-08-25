import 'package:ababilx/features/messages/chat-list/index.dart';
import 'package:ababilx/features/messages/chat-list/recent_contacts_strip.dart';
import 'package:ababilx/features/messages/data/models/chat_conversation.dart';
import 'package:ababilx/features/messages/providers/chat_provider.dart';
import 'package:ababilx/features/profile/data/profile_repository.dart';
import 'package:ababilx/features/profile/providers/profile_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _ChatListNotifier extends ChatNotifier {
  @override
  ChatState build() => const ChatState(
    currentUserId: 'me',
    dms: [
      ChatConversation(
        id: 'dm-1',
        teamId: '',
        scope: 'personal',
        type: 'dm',
        createdAt: '2026-08-25T00:00:00Z',
        lastMessageAt: '2026-08-25T01:00:00Z',
        peerUserId: 'alice',
        peerUserName: 'Alice',
      ),
    ],
  );
}

class _ProfileNotifier extends ProfileNotifier {
  @override
  Future<AppUser> build() async => const AppUser(
    id: 'me',
    name: 'Murad',
    email: 'murad@example.com',
    provider: 'google',
    independentChat: true,
  );
}

void main() {
  testWidgets('chat list mounts recent DM avatars above conversation rows', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatProvider.overrideWith(_ChatListNotifier.new),
          profileProvider.overrideWith(_ProfileNotifier.new),
        ],
        child: const MaterialApp(home: ChatList()),
      ),
    );
    await tester.pump();

    expect(find.byType(RecentContactsStrip), findsOneWidget);
    expect(find.byType(RecentContactTile), findsOneWidget);
    expect(find.text('Alice'), findsNWidgets(2));
  });
}
