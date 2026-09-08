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

  /// One conversation endpoint, by suffix. An EMPTY [action] means the
  /// conversation itself — delete it, rename it — and must not be built by
  /// appending nothing to the path: `/api/chat/conversations/<id>/` is a
  /// different URL to Gin, which answers the trailing slash with a **307**
  /// rather than routing it. Dio surfaces that as a bad response, so deleting
  /// or renaming a personal group failed with a redirect the user could do
  /// nothing about.
  String action(String id, String action) => independent
      ? (action.isEmpty
            ? ApiConstants.independentChatConversation(id)
            : ApiConstants.independentChatConversationAction(id, action))
      : switch (action) {
          'read' => ApiConstants.chatConversationRead(id),
          'mute' => ApiConstants.chatConversationMute(id),
          'pin' => ApiConstants.chatConversationPin(id),
          'hide' => ApiConstants.chatConversationHide(id),
          'accept' => ApiConstants.chatConversationAccept(id),
          'attachments/presign' => ApiConstants.chatConversationPresign(id),
          'attachments/discard' => ApiConstants.chatConversationDiscard(id),
          'e2ee-key' => ApiConstants.chatE2eeConversationKey(id),
          'members' => ApiConstants.chatChannelMembers(id),
          'leave' => ApiConstants.chatChannelLeave(id),
          _ => ApiConstants.chatChannel(id),
        };
  String media(String id) => independent
      ? ApiConstants.independentChatConversationAction(id, 'media')
      : ApiConstants.chatConversationMedia(id);
  String report(String id) => independent
      ? ApiConstants.independentChatConversationAction(id, 'report')
      : ApiConstants.chatConversationReport(id);
  String groupsInCommon(String userId) => independent
      ? ApiConstants.independentChatGroupsInCommon(userId)
      : ApiConstants.chatGroupsInCommon(userId);
  String publicKey(String id) => independent
      ? ApiConstants.independentChatE2eePublicKey(id)
      : ApiConstants.chatE2eePublicKey(id);
}
