/// Base URL for the AbabilX backend.
class ApiConstants {
  ApiConstants._();

  static const String baseUrl = 'https://api.ababilx.cloud';
  static const String webPrivacyPolicyUrl =
      'https://ababilx.cloud/privacy-policy';

  // Auth
  static const String mobileGoogleAuth = '/auth/google/mobile';
  static const String authRefresh = '/auth/refresh';
  static const String qrLoginInfo = '/api/auth/qr/info';
  static const String qrLoginApprove = '/api/auth/qr/approve';
  static const String qrLoginDeny = '/api/auth/qr/deny';

  // User
  static const String me = '/api/me';
  static const String meProfile = '/api/me/profile';
  static const String mePlan = '/api/me/plan';
  static const String meConnections = '/api/me/connections';
  static const String meStatus = '/api/me/status';
  static const String meAcceptPolicy = '/api/me/accept-policy';

  // Team
  static const String teamsMe = '/api/teams/me';
  static const String kanbanBoards = '/api/teams/kanban/boards';
  static String kanbanBoard(String boardId) =>
      '/api/teams/kanban/boards/$boardId';
  static String kanbanBoardTasks(String boardId) =>
      '/api/teams/kanban/boards/$boardId/tasks';
  static String kanbanTask(String taskId) => '/api/teams/kanban/tasks/$taskId';
  static String kanbanTaskMove(String taskId) =>
      '/api/teams/kanban/tasks/$taskId/move';
  static String kanbanTaskComments(String taskId) =>
      '/api/teams/kanban/tasks/$taskId/comments';
  static String kanbanTaskAttachmentsPresign(String taskId) =>
      '/api/teams/kanban/tasks/$taskId/attachments/presign';
  static String kanbanTaskAttachmentsDiscard(String taskId) =>
      '/api/teams/kanban/tasks/$taskId/attachments/discard';

  // CRM
  static const String crmDashboard = '/api/teams/crm/dashboard';
  static const String crmSearch = '/api/teams/crm/search';
  static const String crmConfig = '/api/teams/crm/config';
  static const String crmContacts = '/api/teams/crm/contacts';
  static const String crmOrganizations = '/api/teams/crm/organizations';
  static String crmOrganization(String id) =>
      '/api/teams/crm/organizations/$id';
  static String crmOrganizationRemove(String id) =>
      '/api/teams/crm/organizations/$id/remove';
  static String crmOrganizationDocuments(String id) =>
      '/api/teams/crm/organizations/$id/documents';
  static String crmOrganizationDocumentsPresign(String id) =>
      '/api/teams/crm/organizations/$id/documents/presign';
  static String crmOrganizationDocument(String documentId) =>
      '/api/teams/crm/organization-documents/$documentId';
  static String crmContact(String id) => '/api/teams/crm/contacts/$id';
  static const String crmLeads = '/api/teams/crm/leads';
  static String crmLead(String id) => '/api/teams/crm/leads/$id';
  static String crmLeadPayments(String id) =>
      '/api/teams/crm/leads/$id/payments';
  static String crmPayment(String id) => '/api/teams/crm/payments/$id';
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
  static const String crmFollowupsBulk = '/api/teams/crm/followups/bulk';
  static String crmContactLeads(String contactId) =>
      '/api/teams/crm/contacts/$contactId/leads';
  static const String crmContactImagesPresign =
      '/api/teams/crm/contact-images/presign';
  static const String crmContactImagesDiscard =
      '/api/teams/crm/contact-images/discard';
  static String crmLeadStageUploadsPresign(String leadId) =>
      '/api/teams/crm/leads/$leadId/stage-uploads/presign';
  static String crmStageUpload(String uploadId) =>
      '/api/teams/crm/stage-uploads/$uploadId';

  // Chat
  static const String chatConversations = '/api/teams/chat/conversations';
  static const String chatE2eeVault = '/api/teams/chat/e2ee/vault';
  static String chatE2eePublicKey(String userId) =>
      '/api/teams/chat/e2ee/users/$userId/public-key';
  static String chatE2eeConversationKey(String conversationId) =>
      '/api/teams/chat/conversations/$conversationId/e2ee-key';
  static const String chatChannels = '/api/teams/chat/channels';
  static String chatChannel(String id) => '/api/teams/chat/channels/$id';
  static String chatChannelMembers(String id) =>
      '/api/teams/chat/channels/$id/members';
  static String chatChannelLeave(String id) =>
      '/api/teams/chat/channels/$id/leave';
  static const String chatDm = '/api/teams/chat/dm';
  static String chatVoiceCalls(String conversationId) =>
      '/api/teams/chat/conversations/$conversationId/calls';
  static String chatVoiceCall(String callId) => '/api/teams/chat/calls/$callId';
  static String chatVoiceCallActions(String callId) =>
      '/api/teams/chat/calls/$callId/actions';
  static String chatGroupCall(String conversationId) =>
      '/api/teams/chat/conversations/$conversationId/group-call';
  static String chatGroupCallJoin(String conversationId) =>
      '/api/teams/chat/conversations/$conversationId/group-call/join';
  static String chatGroupCallLeave(String callId) =>
      '/api/teams/chat/group-calls/$callId/leave';
  static String chatGroupCallScreenShare(String callId) =>
      '/api/teams/chat/group-calls/$callId/screen-share';
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
  static String chatConversationHide(String conversationId) =>
      '/api/teams/chat/conversations/$conversationId/hide';
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

  // Workspace Cmd+K search (team premium — all members)
  static const String aiSearchMessages = '/api/ai/search-messages';

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
  static const String messageVaultIdentity = 'ababilx_message_vault_identity';
}
