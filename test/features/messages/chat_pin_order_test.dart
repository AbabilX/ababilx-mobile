import 'package:flutter_test/flutter_test.dart';

import 'package:ababilx/features/messages/chat_list_filters.dart';
import 'package:ababilx/features/messages/data/models/chat_models.dart';

ChatConversation _conv(
  String id, {
  required String lastMessageAt,
  bool pinned = false,
  int unreadCount = 0,
}) => ChatConversation(
  id: id,
  teamId: '',
  scope: 'personal',
  type: 'dm',
  createdAt: '2026-09-01T00:00:00Z',
  lastMessageAt: lastMessageAt,
  pinned: pinned,
  unreadCount: unreadCount,
);

void main() {
  test('pinned chats sort above everything else', () {
    final rows = unifiedConversations(
      dms: [
        _conv('newest', lastMessageAt: '2026-09-09T12:00:00Z'),
        _conv('pinned-old', lastMessageAt: '2026-01-01T00:00:00Z', pinned: true),
        _conv('older', lastMessageAt: '2026-09-08T12:00:00Z'),
      ],
      channels: const [],
    );
    expect(rows.map((c) => c.id), ['pinned-old', 'newest', 'older']);
  });

  test('within the pinned block the newest still wins', () {
    // A pin says "keep this reachable", not "freeze it in place" — a pinned
    // chat that just got a message must not sit under a quiet one.
    final rows = unifiedConversations(
      dms: [
        _conv('pin-quiet', lastMessageAt: '2026-02-01T00:00:00Z', pinned: true),
        _conv('pin-busy', lastMessageAt: '2026-09-09T12:00:00Z', pinned: true),
        _conv('loose', lastMessageAt: '2026-09-09T13:00:00Z'),
      ],
      channels: const [],
    );
    expect(rows.map((c) => c.id), ['pin-busy', 'pin-quiet', 'loose']);
  });

  test('the unread filter still applies to pinned chats', () {
    // Pinning is ordering, not an exemption: a read pin has nothing unread in
    // it and must not survive the Unread filter.
    final rows = unifiedConversations(
      dms: [
        _conv('pin-read', lastMessageAt: '2026-09-09T12:00:00Z', pinned: true),
        _conv('loose-unread', lastMessageAt: '2026-09-08T12:00:00Z', unreadCount: 2),
      ],
      channels: const [],
      filter: ChatListFilter.unread,
    );
    expect(rows.map((c) => c.id), ['loose-unread']);
  });

  test('pinned survives the JSON round trip and defaults to false', () {
    final base = {
      'id': 'c1',
      'type': 'dm',
      'scope': 'personal',
      'created_at': '2026-09-09T00:00:00Z',
    };
    expect(ChatConversation.fromJson({...base, 'pinned': true}).pinned, isTrue);
    expect(ChatConversation.fromJson(base).pinned, isFalse);
  });
}
