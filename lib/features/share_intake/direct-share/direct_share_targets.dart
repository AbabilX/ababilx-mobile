import '../../messages/chat-recipient-picker/chat_recipient_target.dart';
import '../../messages/data/models/chat_conversation.dart';

/// How many chats the system share sheet is offered. It shows four to eight.
const directShareLimit = 8;

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
