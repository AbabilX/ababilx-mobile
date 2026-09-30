import '../../messages/chat-recipient-picker/chat_recipient_target.dart';
import '../../messages/data/models/chat_conversation.dart';

/// How many chats the system share sheet is offered. It shows four to eight.
const directShareLimit = 8;

/// Newest message time of each chat [directShareTargets] would publish.
Map<String, String> directShareActivity(List<ChatConversation> shareable) => {
  for (final c
      in shareable.where((c) => !c.isIncomingRequest).take(directShareLimit))
    c.id: c.lastMessageAt ?? '',
};

/// Chats in [now] that had a message since [before], oldest first so the
/// busiest reaches Android last. Nothing on the first look of a launch
/// ([before] empty): that is a cold list, not activity — the Kotlin side
/// seeds a new account on its own.
///
/// Compared as instants, and only a NEWER one counts: deleting the last
/// message moves the time back, and a sidebar refetch can write the same
/// instant in another format — neither is somebody using the chat.
List<String> directShareUsed(
  Map<String, String> before,
  Map<String, String> now,
) {
  if (before.isEmpty) return const [];
  final times = <String, DateTime>{
    for (final e in now.entries) e.key: ?DateTime.tryParse(e.value),
  };
  final used = [
    for (final e in times.entries)
      if (DateTime.tryParse(before[e.key] ?? '') case final was
          when was == null || e.value.isAfter(was))
        e.key,
  ]..sort((a, b) => times[a]!.compareTo(times[b]!));
  return used;
}

/// The Direct Share targets for [shareable] (already filtered and ordered by
/// `shareableConversations`), as the channel sends them to Kotlin.
///
/// A stranger's unanswered request is left out: their face in another app's
/// share sheet would read as a contact the user chose.
List<Map<String, Object>> directShareTargets(
  List<ChatConversation> shareable,
  String currentUserId,
) => shareable.where((c) => !c.isIncomingRequest).take(directShareLimit).map((
  c,
) {
  final target = ChatRecipientTarget.conversation(c, currentUserId);
  return <String, Object>{
    'id': target.id,
    'name': target.name,
    'avatarUrl': target.avatarUrl,
    'isGroup': target.isGroup,
  };
}).toList();
