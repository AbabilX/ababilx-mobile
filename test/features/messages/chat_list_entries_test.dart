import 'package:ababilx/features/local_share/data/share_thread_queries.dart';
import 'package:ababilx/features/local_share/engine/protocol/share_envelope.dart';
import 'package:ababilx/features/local_share/engine/store/share_records.dart';
import 'package:ababilx/features/messages/chat-list/chat_list_entries.dart';
import 'package:ababilx/features/messages/chat_list_filters.dart';
import 'package:ababilx/features/messages/data/models/chat_conversation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  int ms(String iso) => DateTime.parse(iso).millisecondsSinceEpoch;

  ChatConversation chat(String id, String at, {bool pinned = false}) =>
      ChatConversation(
        id: id,
        teamId: '',
        type: 'dm',
        createdAt: at,
        lastMessageAt: at,
        pinned: pinned,
      );

  ShareThread thread(String id, String at, {int unread = 0}) => ShareThread(
    device: ShareDeviceRecord(deviceId: id, name: id, deviceType: 'mobile'),
    unread: unread,
    last: ShareMessageRecord(
      id: 'm-$id',
      deviceId: id,
      fromMe: false,
      kind: ShareKind.text,
      sentAt: ms(at),
      status: ShareMessageStatus.done,
      text: 'hi',
    ),
    lastOrderMs: ms(at),
  );

  List<String> keys(List<ChatListEntry> entries) =>
      entries.map((e) => e.key).toList();

  final chats = [
    chat('pin', '2026-10-01T00:00:00Z', pinned: true),
    chat('new', '2026-10-05T10:00:00Z'),
    chat('old', '2026-10-03T10:00:00Z'),
  ];

  test('no threads leaves the list as it was', () {
    expect(keys(mergeChatListEntries(conversations: chats, threads: [])), [
      'pin',
      'new',
      'old',
    ]);
  });

  test('a thread never replaces a conversation, even with the same person', () {
    final dm = ChatConversation(
      id: 'dm',
      teamId: '',
      type: 'dm',
      createdAt: '2026-10-05T10:00:00Z',
      lastMessageAt: '2026-10-05T10:00:00Z',
      peerUserId: 'u1',
    );
    final t = ShareThread(
      device: ShareDeviceRecord(
        deviceId: 'd1',
        name: 'd1',
        deviceType: 'mobile',
        userId: 'u1',
      ),
      unread: 0,
      last: null,
      lastOrderMs: ms('2026-10-05T11:00:00Z'),
    );
    final merged = mergeChatListEntries(conversations: [dm], threads: [t]);
    expect(keys(merged), ['local-share:d1', 'dm']);
  });

  test('a thread takes its place by time, under the pinned block', () {
    final merged = mergeChatListEntries(
      conversations: chats,
      threads: [
        thread('mid', '2026-10-04T10:00:00Z'),
        thread('newest', '2026-10-05T12:00:00Z'),
        thread('oldest', '2026-09-01T10:00:00Z'),
      ],
    );
    expect(keys(merged), [
      'pin',
      'local-share:newest',
      'new',
      'local-share:mid',
      'old',
      'local-share:oldest',
    ]);
  });

  test('every chat pinned: threads go after them', () {
    final merged = mergeChatListEntries(
      conversations: [chats.first],
      threads: [thread('a', '2026-10-05T12:00:00Z')],
    );
    expect(keys(merged), ['pin', 'local-share:a']);
  });

  test('unread keeps only threads with something unread', () {
    final merged = mergeChatListEntries(
      conversations: const [],
      threads: [
        thread('read', '2026-10-05T12:00:00Z'),
        thread('unread', '2026-10-04T12:00:00Z', unread: 2),
      ],
      filter: ChatListFilter.unread,
    );
    expect(keys(merged), ['local-share:unread']);
  });

  test('groups and feeds never show a device thread', () {
    for (final filter in [ChatListFilter.groups, ChatListFilter.webhooks]) {
      expect(
        mergeChatListEntries(
          conversations: const [],
          threads: [thread('a', '2026-10-05T12:00:00Z', unread: 1)],
          filter: filter,
        ),
        isEmpty,
      );
    }
  });

  test('local share filter shows device threads and no conversations', () {
    final merged = mergeChatListEntries(
      conversations: const [],
      threads: [thread('a', '2026-10-04T10:00:00Z')],
      filter: ChatListFilter.localShare,
    );
    expect(keys(merged), ['local-share:a']);
    expect(
      availableChatListFilters(chats, hasShareThreads: true),
      contains(ChatListFilter.localShare),
    );
    expect(
      availableChatListFilters(chats),
      isNot(contains(ChatListFilter.localShare)),
    );
  });

  test('a pinned thread joins the pinned block by time', () {
    final merged = mergeChatListEntries(
      conversations: [
        chat('pinNew', '2026-10-05T00:00:00Z', pinned: true),
        chat('pinOld', '2026-10-01T00:00:00Z', pinned: true),
        chat('new', '2026-10-05T10:00:00Z'),
      ],
      threads: [
        thread('mid', '2026-10-03T10:00:00Z'),
        thread('pinned', '2026-10-02T10:00:00Z'),
        thread('free', '2026-10-06T10:00:00Z'),
      ],
      pinnedThreads: {'pinned'},
    );
    expect(keys(merged), [
      'pinNew',
      'local-share:pinned',
      'pinOld',
      'local-share:free',
      'new',
      'local-share:mid',
    ]);
    expect(merged.whereType<ShareThreadEntry>().map((e) => e.pinned), [
      true,
      false,
      false,
    ]);
  });

  test('a pinned thread with no pinned conversations sits first', () {
    final merged = mergeChatListEntries(
      conversations: [chats[1], chats[2]],
      threads: [thread('old', '2026-08-01T10:00:00Z')],
      pinnedThreads: {'old'},
    );
    expect(keys(merged), ['local-share:old', 'new', 'old']);
  });
}
