import '../../../shared/text/name_search.dart';
import '../data/models/chat_models.dart';
import '../nickname/contact_nickname.dart';
import '../nickname/nickname_title.dart';

/// Sidebar chats whose name matches [query], in the order they were given.
///
/// The reference Android app's list search puts this section first
/// (`ContactSearchConfiguration.Section.Chats`): a thread whose contact name
/// or group title matches, not a keyword hit inside a message. Matching is
/// local — the conversations are already on this phone.
///
/// Nickname, the account's own display name, and a group's title/slug are all
/// searched so a rename on this device does not hide the original name.
List<ChatConversation> matchingSearchConversations(
  List<ChatConversation> conversations,
  String query, {
  required ContactNicknames nicknames,
  String? currentUserId,
}) {
  if (query.trim().isEmpty) return const [];
  return [
    for (final conversation in conversations)
      if (conversationMatchesSearch(
        conversation,
        query,
        nicknames: nicknames,
        currentUserId: currentUserId,
      ))
        conversation,
  ];
}

bool conversationMatchesSearch(
  ChatConversation conversation,
  String query, {
  required ContactNicknames nicknames,
  String? currentUserId,
}) {
  return matchesNameQuery(query, [
    nicknames.titleFor(conversation, currentUserId),
    conversation.displayTitle(currentUserId),
    conversation.peerUserName,
    conversation.name,
    conversation.slug,
  ]);
}
