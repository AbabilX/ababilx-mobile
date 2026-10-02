import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../privacy-mode/peer_privacy_provider.dart';
import '../data/models/chat_connection.dart';
import '../data/models/chat_conversation.dart';
import 'chat_connections_provider.dart';
import 'chat_provider.dart';

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
///   accepted connection · open DM · request I sent
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

/// Everyone a group can take: accepted connections, and nobody else.
///
/// Narrower than [messageablePeopleProvider] on purpose, and the server
/// enforces it (`CanInviteToGroup`): a DM to a stranger is a request they can
/// refuse, but nobody gets a prompt before landing in a group. Offering anyone
/// else here only to have the add answer `connection_required` would be a dead
/// row.
///
/// A connection in privacy mode is left out too: nobody may add them to a
/// group (`peer_privacy_mode`). A live `chat.peer_privacy` flip wins over the
/// connection list's flag, which is only as fresh as its last fetch.
final groupInvitablePeopleProvider = Provider<List<ChatUserSummary>>((ref) {
  final me = ref.watch(chatProvider.select((s) => s.currentUserId));
  final live = ref.watch(peerPrivacyOverridesProvider);
  return [
    for (final connection in ref.watch(chatConnectionsProvider).connections)
      if (connection.user.userId != me &&
          !(live[connection.user.userId] ?? connection.user.privacyMode))
        connection.user,
  ]..sort((a, b) => a.name.compareTo(b.name));
});
