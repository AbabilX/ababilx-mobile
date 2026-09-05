import 'package:ababilx/features/messages/chat-details/groups_in_common_section.dart';
import 'package:ababilx/features/messages/chat-details/shared_media_section.dart';
import 'package:ababilx/features/messages/data/models/chat_models.dart';
import 'package:ababilx/features/messages/providers/chat_details_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shared media parsing', () {
    test('reads a page', () {
      final page = ChatMediaPage.fromJson({
        'items': [
          {
            'id': 'a1',
            'message_id': 'm1',
            'file_name': 'cat.jpg',
            'file_url': 'https://cdn/cat.jpg',
            'content_type': 'image/jpeg',
            'size_bytes': 1234,
            'created_at': '2026-09-05T10:00:00Z',
          },
        ],
        'next_cursor': '2026-09-05T10:00:00Z|m1',
        'has_more': true,
      });
      expect(page.items.single.fileName, 'cat.jpg');
      expect(page.items.single.isImage, isTrue);
      expect(page.nextCursor, '2026-09-05T10:00:00Z|m1');
      expect(page.hasMore, isTrue);
    });

    // An older server that never learned this endpoint's shape must read as an
    // empty page, not as a crash inside the details screen.
    test('an empty body is an empty page', () {
      final page = ChatMediaPage.fromJson(const {});
      expect(page.items, isEmpty);
      expect(page.hasMore, isFalse);
      expect(page.nextCursor, '');
    });
  });

  test('groups in common parses both lists', () {
    final data = ChatGroupsInCommon.fromJson({
      'in_common': [
        {'id': 'g1', 'name': 'Devs', 'member_count': 4},
      ],
      'can_add': [
        {'id': 'g2', 'name': 'Vintage Dev', 'member_count': 9},
      ],
    });
    expect(data.inCommon.single.name, 'Devs');
    expect(data.inCommon.single.memberCount, 4);
    expect(data.canAdd.single.id, 'g2');
  });

  testWidgets('shared media draws nothing when the chat has no files', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatSharedMediaProvider(
            'c1',
          ).overrideWith((ref) async => const ChatMediaPage.empty()),
        ],
        child: const MaterialApp(
          home: Scaffold(body: SharedMediaSection(conversationId: 'c1')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Shared media'), findsNothing);
    expect(find.text('See all'), findsNothing);
  });

  Widget groupsHost(ChatGroupsInCommon data) => ProviderScope(
    overrides: [
      chatGroupsInCommonProvider('u1').overrideWith((ref) async => data),
    ],
    child: const MaterialApp(
      home: Scaffold(
        body: GroupsInCommonSection(peerUserId: 'u1', peerName: 'Badhon'),
      ),
    ),
  );

  // A heading over nothing is a row that only ever says "no", so both halves
  // being empty hides the block entirely.
  testWidgets('groups in common hides when there are none either way', (
    tester,
  ) async {
    await tester.pumpWidget(groupsHost(const ChatGroupsInCommon.empty()));
    await tester.pumpAndSettle();
    expect(find.textContaining('in common'), findsNothing);
  });

  testWidgets('groups in common lists a shared group', (tester) async {
    await tester.pumpWidget(
      groupsHost(
        const ChatGroupsInCommon(
          inCommon: [
            ChatGroupSummary(
              id: 'g1',
              name: 'Devs',
              avatarUrl: '',
              memberCount: 4,
              scope: 'personal',
              type: 'group',
            ),
          ],
          canAdd: [],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('1 group in common'), findsOneWidget);
    expect(find.text('Devs'), findsOneWidget);
    // No add row: the server offered nothing to add them to.
    expect(find.text('Add to a group'), findsNothing);
  });
}
