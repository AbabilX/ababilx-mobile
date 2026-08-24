import '../../../core/constants/api_constants.dart';

class ChatEndpoints {
  const ChatEndpoints({required this.independent});

  final bool independent;

  String get conversations => independent
      ? ApiConstants.independentChatConversations
      : ApiConstants.chatConversations;
  String get dm =>
      independent ? ApiConstants.independentChatDm : ApiConstants.chatDm;
  String get forward => independent
      ? ApiConstants.independentChatForward
      : ApiConstants.chatForward;
  String get search => independent
      ? ApiConstants.independentChatSearch
      : ApiConstants.chatSearch;
  String get callLog => independent
      ? ApiConstants.independentChatCallLog
      : ApiConstants.chatCallLog;
  String messages(String id) => independent
      ? ApiConstants.independentChatMessages(id)
      : ApiConstants.chatMessages(id);
  String message(String id) => independent
      ? ApiConstants.independentChatMessage(id)
      : ApiConstants.chatMessage(id);
  String reactions(String id) => independent
      ? ApiConstants.independentChatMessageReactions(id)
      : ApiConstants.chatMessageReactions(id);
  String action(String id, String action) => independent
      ? ApiConstants.independentChatConversationAction(id, action)
      : switch (action) {
          'read' => ApiConstants.chatConversationRead(id),
          'mute' => ApiConstants.chatConversationMute(id),
          'hide' => ApiConstants.chatConversationHide(id),
          'attachments/presign' => ApiConstants.chatConversationPresign(id),
          'attachments/discard' => ApiConstants.chatConversationDiscard(id),
          'e2ee-key' => ApiConstants.chatE2eeConversationKey(id),
          'members' => ApiConstants.chatChannelMembers(id),
          'leave' => ApiConstants.chatChannelLeave(id),
          _ => ApiConstants.chatChannel(id),
        };
  String publicKey(String id) => independent
      ? ApiConstants.independentChatE2eePublicKey(id)
      : ApiConstants.chatE2eePublicKey(id);
}
