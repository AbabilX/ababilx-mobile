/// Base URL for the AbabilX backend.
class ApiConstants {
  ApiConstants._();

  static const String baseUrl = 'https://api.ababilx.cloud';

  // Auth
  static const String mobileGoogleAuth = '/auth/google/mobile';
  static const String authRefresh = '/auth/refresh';

  // User
  static const String me = '/api/me';
  static const String meProfile = '/api/me/profile';
  static const String mePlan = '/api/me/plan';
  static const String meConnections = '/api/me/connections';

  // Team
  static const String teamsMe = '/api/teams/me';

  // CRM
  static const String crmConfig = '/api/teams/crm/config';
  static const String crmContacts = '/api/teams/crm/contacts';
  static String crmContact(String id) => '/api/teams/crm/contacts/$id';
  static const String crmLeads = '/api/teams/crm/leads';
  static String crmLead(String id) => '/api/teams/crm/leads/$id';
  static String crmLeadStage(String id) => '/api/teams/crm/leads/$id/stage';
  static String crmLeadTimeline(String id) =>
      '/api/teams/crm/leads/$id/timeline';
  static String crmLeadNotes(String id) => '/api/teams/crm/leads/$id/notes';
  static String crmNote(String noteId) => '/api/teams/crm/notes/$noteId';
  static String crmLeadActivities(String id) =>
      '/api/teams/crm/leads/$id/activities';
  static String crmLeadDocuments(String id) =>
      '/api/teams/crm/leads/$id/documents';
  static String crmLeadDocumentsPresign(String id) =>
      '/api/teams/crm/leads/$id/documents/presign';
  static const String crmDocumentsDiscard = '/api/teams/crm/documents/discard';
  static String crmDocument(String docId) => '/api/teams/crm/documents/$docId';
  static const String crmFollowups = '/api/teams/crm/followups';
  static String crmFollowup(String id) => '/api/teams/crm/followups/$id';
  static String crmContactLeads(String contactId) =>
      '/api/teams/crm/contacts/$contactId/leads';

  // Chat
  static const String chatConversations = '/api/teams/chat/conversations';
  static const String chatChannels = '/api/teams/chat/channels';
  static String chatChannel(String id) => '/api/teams/chat/channels/$id';
  static String chatChannelMembers(String id) =>
      '/api/teams/chat/channels/$id/members';
  static String chatChannelLeave(String id) =>
      '/api/teams/chat/channels/$id/leave';
  static const String chatDm = '/api/teams/chat/dm';
  static const String chatForward = '/api/teams/chat/forward';
  static String chatMessages(String conversationId) =>
      '/api/teams/chat/conversations/$conversationId/messages';
  static String chatMessage(String messageId) =>
      '/api/teams/chat/messages/$messageId';
  static String chatMessageReactions(String messageId) =>
      '/api/teams/chat/messages/$messageId/reactions';
  static String chatConversationRead(String conversationId) =>
      '/api/teams/chat/conversations/$conversationId/read';
  static String chatConversationMute(String conversationId) =>
      '/api/teams/chat/conversations/$conversationId/mute';
  static String chatConversationPresign(String conversationId) =>
      '/api/teams/chat/conversations/$conversationId/attachments/presign';
  static String chatConversationDiscard(String conversationId) =>
      '/api/teams/chat/conversations/$conversationId/attachments/discard';
  static const String chatSearch = '/api/teams/chat/search';

  // Wall
  static const String wallPosts = '/api/teams/wall/posts';
  static String wallPost(String id) => '/api/teams/wall/posts/$id';
  static String wallPostComments(String id) =>
      '/api/teams/wall/posts/$id/comments';
  static String wallPostComment(String postId, String commentId) =>
      '/api/teams/wall/posts/$postId/comments/$commentId';
  static String wallPostReactions(String id) =>
      '/api/teams/wall/posts/$id/reactions';
  static String wallPostSave(String id) => '/api/teams/wall/posts/$id/save';
  static const String wallAttachmentsPresign =
      '/api/teams/wall/posts/attachments/presign';
  static const String wallAttachmentsDiscard =
      '/api/teams/wall/posts/attachments/discard';
  static const String wallCategories = '/api/teams/wall/categories';
  static const String wallStats = '/api/teams/wall/stats';
  static const String wallSearch = '/api/teams/wall/search';
  static const String wallForward = '/api/teams/wall/forward';
  static const String meWallSaves = '/api/me/wall/saves';

  // Devices (FCM)
  static const String devices = '/api/devices';

  // WebSocket
  static const String notificationsStream = '/api/notifications/stream';
  static const String wsAuthSubprotocol = 'ababilx-ws';

  static String get notificationsWsUrl {
    final wsBase = baseUrl.replaceFirst('https://', 'wss://');
    return '$wsBase$notificationsStream';
  }
}

class StorageKeys {
  StorageKeys._();

  static const String jwt = 'ababilx_jwt';
  static const String refreshToken = 'ababilx_refresh_token';
  static const String fcmToken = 'ababilx_fcm_token';
}
