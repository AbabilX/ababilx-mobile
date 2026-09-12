import '../../../shared/text/name_search.dart';
import '../data/models/chat_connection.dart';
import '../data/models/chat_conversation.dart';
import 'chat_recipient_target.dart';

/// The three sections the picker draws, already filtered.
class ChatRecipientSections {
  const ChatRecipientSections({
    required this.recent,
    required this.groups,
    required this.contacts,
  });

  final List<ChatRecipientTarget> recent;
  final List<ChatRecipientTarget> groups;
  final List<ChatRecipientTarget> contacts;
}

/// How many chats the idle list shows before the Groups section takes over.
const int chatRecipientRecentLimit = 7;

/// Builds the picker's sections.
///
/// **Searching looks at every local conversation, not only the ones drawn.**
/// The idle list is Signal's: the newest few chats, then the groups below
/// them. Filtering those two lists meant a DM sitting at position eight was in
/// no section at all — typing that person's name found nothing, and the only
/// row left for them was the contact one, which is a `person` target with no
/// conversation behind it and has to open a DM before anything can be sealed
/// for it. A query therefore matches the whole list and answers as one
/// Results section.
///
/// A person already on screen as a chat is dropped from Contacts for the same
/// reason: two rows for one person, sending by two different routes, is a
/// choice nobody can make correctly.
ChatRecipientSections buildChatRecipientSections({
  required List<ChatConversation> conversations,
  required List<ChatUserSummary> people,
  required String currentUserId,
  required String query,
  int recentLimit = chatRecipientRecentLimit,
}) {
  final searching = query.trim().isNotEmpty;
  ChatRecipientTarget targetOf(ChatConversation c) =>
      ChatRecipientTarget.conversation(c, currentUserId);

  final shown = <ChatConversation>[];
  final groups = <ChatRecipientTarget>[];
  if (searching) {
    for (final conversation in conversations) {
      if (matchesNameQuery(query, [targetOf(conversation).name])) {
        shown.add(conversation);
      }
    }
  } else {
    shown.addAll(conversations.take(recentLimit));
    for (final conversation in conversations.skip(recentLimit)) {
      if (conversation.isGroupConversation) groups.add(targetOf(conversation));
    }
  }

  final shownPeerIds = <String>{
    for (final conversation in shown)
      if ((conversation.peerUserId ?? '').isNotEmpty) conversation.peerUserId!,
  };

  final contacts = <ChatRecipientTarget>[];
  for (final person in people) {
    if (shownPeerIds.contains(person.userId)) continue;
    if (searching && !matchesNameQuery(query, [person.name, person.username])) {
      continue;
    }
    contacts.add(ChatRecipientTarget.person(person));
  }

  return ChatRecipientSections(
    recent: [for (final conversation in shown) targetOf(conversation)],
    groups: groups,
    contacts: contacts,
  );
}
