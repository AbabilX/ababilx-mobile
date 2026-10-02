import 'dart:async';

import '../../../shared/avatar-store/avatar_picture.dart';
import '../../../shared/avatar-store/avatar_store.dart';
import '../data/models/chat_conversation.dart';

typedef AvatarRef = ({String url, String? owner});

/// Whose picture a conversation's avatar is: the DM peer, or the group itself
/// for a group's own photo. Null for a note to self.
String? conversationAvatarOwner(ChatConversation c) {
  if (c.isSelf) return null;
  if (c.isGroupConversation) return 'conv:${c.id}';
  final peer = c.peerUserId?.trim() ?? '';
  return peer.isEmpty ? null : 'user:$peer';
}

/// Every picture a chat-list row draws, in the order they appear on it. Must
/// follow `ConversationAvatar` / `GroupAvatarStack`'s precedence, or a warmed
/// picture is not the one that row asks for.
Iterable<AvatarRef> conversationAvatarRefs(ChatConversation c) sync* {
  if (c.isSelf) return;
  if (c.isGroupConversation) {
    final own = c.avatarUrl?.trim() ?? '';
    if (own.isNotEmpty) {
      yield (url: own, owner: conversationAvatarOwner(c));
      return;
    }
    if (c.isWebhook) return;
    final pics = c.memberAvatars.where((u) => u.trim().isNotEmpty).take(2);
    for (final url in pics) {
      yield (url: url, owner: null);
    }
    return;
  }
  if (c.isAccountDeleted) return;
  final url = c.peerUserAvatar?.trim() ?? '';
  if (url.isNotEmpty) yield (url: url, owner: conversationAvatarOwner(c));
}

/// Cold start: decode the faces of the first rows before the cached list is
/// painted, so it paints with them — WhatsApp's chat list never shows a
/// letter for a face it has. Bounded, so a slow phone is never held back.
Future<void> warmChatListAvatars(
  Iterable<ChatConversation> rows, {
  int rowsToWarm = 24,
}) => warmAvatarFiles(rows.take(rowsToWarm).expand(conversationAvatarRefs));

/// After the server's list lands: put every chat's picture on the phone, in
/// the background, so chats never scrolled to are instant too. A changed photo
/// is fetched here as well and swaps in under the old one.
void prefetchChatListAvatars(Iterable<ChatConversation> rows) {
  final store = AvatarStore.instance;
  for (final ref in rows.expand(conversationAvatarRefs)) {
    unawaited(store.ensure(ref.url, owner: ref.owner));
  }
}
