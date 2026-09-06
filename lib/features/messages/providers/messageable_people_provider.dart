import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/chat_connection.dart';
import '../data/models/chat_conversation.dart';
import 'chat_connections_provider.dart';
import 'chat_provider.dart';
import 'team_gate_provider.dart';

/// Everyone the New message screen offers before anything is typed.
///
/// Under the message-request model a connection is not a precondition for
/// messaging, so "accepted connections" is far too narrow a source on its own:
/// `GET /api/chat/connections` returns `status = 'accepted'` and nothing else,
/// which left someone you had just written to — or just asked to connect —
/// absent from this list, and reachable only by searching for them again.
///
/// The rule is now "anyone I already have something open with":
///
///   accepted connection · open DM · request I sent · workspace colleague
///
/// Blocked peers are excluded, and the richest summary wins where a person
/// arrives from more than one source — a connection carries a username and a
/// real avatar, a DM row carries only what the sidebar needed.
final messageablePeopleProvider = Provider<List<ChatUserSummary>>((ref) {
  final chat = ref.watch(chatProvider);
  final connections = ref.watch(chatConnectionsProvider);
  final me = chat.currentUserId;
  final people = <String, ChatUserSummary>{};

  for (final connection in connections.connections) {
    people[connection.user.userId] = connection.user;
  }
  for (final request in connections.sent) {
    people.putIfAbsent(request.user.userId, () => request.user);
  }
  for (final dm in chat.dms) {
    final peer = _dmPeer(dm, me);
    if (peer != null) people.putIfAbsent(peer.userId, () => peer);
  }
  for (final member in ref.watch(teamMembersProvider)) {
    if (member.userId == me) continue;
    people.putIfAbsent(
      member.userId,
      () => ChatUserSummary(
        userId: member.userId,
        name: member.displayName,
        avatarUrl: member.avatarUrl ?? '',
        sharedWorkspace: true,
        canMessage: true,
      ),
    );
  }

  final result = people.values.toList();
  result.sort((a, b) => a.name.compareTo(b.name));
  return result;
});

/// The other side of a DM, or null when the row cannot stand in for a person:
/// no peer id, myself, or a thread the server has locked, which on a DM means
/// a block.
ChatUserSummary? _dmPeer(ChatConversation dm, String? me) {
  final id = dm.peerUserId ?? '';
  if (id.isEmpty || id == me || !dm.canMessage) return null;
  return ChatUserSummary(
    userId: id,
    name: dm.peerUserName ?? '',
    avatarUrl: dm.peerUserAvatar ?? '',
    canMessage: true,
  );
}
