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
}
