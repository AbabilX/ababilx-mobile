import '../data/models/chat_models.dart';
import 'contact_nickname.dart';

/// The one place that decides what a conversation is called on this device.
///
/// A DM is titled by a person, so a nickname set here wins over the name that
/// account chose. A channel or a group is titled by the conversation itself,
/// which nobody has a private name for.
extension ConversationNicknameTitle on ContactNicknames {
  String titleFor(ChatConversation conversation, String? currentUserId) {
    // A note to self is a DM with no second person: its "peer" is the viewer,
    // so a nickname they set for themselves elsewhere would rename the thread.
    if (!conversation.hasDmPeer) {
      return conversation.displayTitle(currentUserId);
    }
    return resolve(
      userId: conversation.peerUserId,
      name: conversation.peerUserName,
      fallback: 'Direct message',
    );
  }
}
