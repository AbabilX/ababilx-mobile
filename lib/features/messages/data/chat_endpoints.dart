import '../../../core/constants/api_constants.dart';

/// The chat routes. There is one set: `/api/chat/*`.
///
/// It used to switch between those and `/api/teams/chat/*` on the
/// `independent_chat` capability. Since the server's migration 0145 no
/// conversation belongs to a workspace and the independent routes are always
/// registered, so there is nothing left to switch on. The server keeps the
/// team paths for builds that predate this one.
class ChatEndpoints {
  const ChatEndpoints();

  String get conversations => ApiConstants.independentChatConversations;
  String get dm => ApiConstants.independentChatDm;
  String get forward => ApiConstants.independentChatForward;
  String get search => ApiConstants.independentChatSearch;
  String get callLog => ApiConstants.independentChatCallLog;
  String messages(String id) => ApiConstants.independentChatMessages(id);
  String message(String id) => ApiConstants.independentChatMessage(id);
  String reactions(String id) =>
      ApiConstants.independentChatMessageReactions(id);

  /// One conversation endpoint, by suffix. An EMPTY [action] means the
  /// conversation itself — delete it — and must not be built by appending
  /// nothing to the path: `/api/chat/conversations/<id>/` is a different URL
  /// to Gin, which answers the trailing slash with a **307** rather than
  /// routing it. Dio surfaces that as a bad response, so deleting a group
  /// failed with a redirect the user could do nothing about.
  String action(String id, String action) => action.isEmpty
      ? ApiConstants.independentChatConversation(id)
      : ApiConstants.independentChatConversationAction(id, action);
  String media(String id) =>
      ApiConstants.independentChatConversationAction(id, 'media');
  String report(String id) =>
      ApiConstants.independentChatConversationAction(id, 'report');
  String groupsInCommon(String userId) =>
      ApiConstants.independentChatGroupsInCommon(userId);
  String publicKey(String id) => ApiConstants.independentChatE2eePublicKey(id);
}
