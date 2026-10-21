/// Base URL for the AbabilX backend.
class ApiConstants {
  static const chatDeletions = "/api/me/chat-deletions";
  static const chatRestoreMessageCount = "/api/chat/recovery/message-count";
  ApiConstants._();

  /// `--dart-define=ABABILX_API_URL=http://<mac-ip>:7896` points a debug build
  /// at the local stack (ababilx-server/local); release builds never set it.
  static const String baseUrl = String.fromEnvironment(
    'ABABILX_API_URL',
    defaultValue: 'https://api.ababilx.com',
  );
  static const String webPrivacyPolicyUrl =
      'https://ababilx.com/privacy-policy';

  // Auth
  static const String mobileGoogleAuth = '/auth/google/mobile';
  static const String emailSignup = '/auth/email/signup';
  static const String emailVerify = '/auth/email/verify';
  static const String emailLogin = '/auth/email/login';
  static const String emailReset = '/auth/email/reset';
  static const String emailResetConfirm = '/auth/email/reset/confirm';
  static const String authRefresh = '/auth/refresh';
  static const String deviceChallenge = '/auth/device/challenge';
  static const String deviceRegister = '/auth/device/register';
  static const String deviceLogin = '/auth/device/login';
  static const String qrLoginInfo = '/api/auth/qr/info';
  static const String qrLoginApprove = '/api/auth/qr/approve';
  static const String qrLoginDeny = '/api/auth/qr/deny';

  // User
  static const String me = '/api/me';
  static const String meProfile = '/api/me/profile';
  static const String meStatus = '/api/me/status';
  static const String meAcceptPolicy = '/api/me/accept-policy';
  static const String meSessions = '/api/me/sessions';
  static const String meSessionsRevokeOthers = '/api/me/sessions/revoke-others';
  static const String meDiscovery = '/api/me/discovery';
  static const String meTypingIndicators = '/api/me/typing-indicators';
  static const String meBackupKey = '/api/me/backup-key';

  /// Public update check (no auth): `?platform=android&build=30`.
  static const String appVersion = '/v1/api/app/version';

  /// Privacy mode (server migration 0152): typing, receipts, presence,
  /// ringing and connected-call history withheld from DM peers.
  static const String mePrivacyMode = '/api/me/privacy-mode';

  /// Per-person privacy (server migration 0153): GET lists the choices,
  /// PUT `.../people/:userId` `{mode: default|always|never}` sets one.
  static const String mePrivacyPeople = '/api/me/privacy-mode/people';

  /// The caller's own live 1:1 call, for a client that lost track of one.
  static const String meActiveCall = '/api/me/active-call';
  static const String meName = '/api/me/name';
  static const String meUsername = '/api/me/username';
  static const String mePassword = '/api/me/password';
  static const String mePasswordCode = '/api/me/password/code';
  static const String meEmail = '/api/me/email';
  static const String meEmailCode = '/api/me/email/code';
  static const String meUploadPresign = '/api/me/upload/presign';

  // Chat
  static const String chatConversations = '/api/teams/chat/conversations';

  /// Resolve one exact handle to a person — what a scanned QR code carries.
  ///
  /// Deliberately the team-prefixed path, which is registered whether or not
  /// ABABILX_INDEPENDENT_CHAT is on. The handler needs no team: it takes the
  /// caller's id and a username, so a scan works on either build.
  static String chatHandle(String username) =>
      '/api/teams/chat/handles/${Uri.encodeComponent(username)}';
  static const String chatRecoverySession = '/api/chat/recovery/start-session';
  static const String chatRecoveryChallenge =
      '/api/chat/recovery/reveal/challenge';
  static const String chatRecoveryVerify = '/api/chat/recovery/reveal/verify';
  static const String chatE2eeVault = '/api/teams/chat/e2ee/vault';
  // Sheds the retired PIN-wrapped copy of the identity once a device holds it.
  static const String chatE2eeWrappedKey = '/api/teams/chat/e2ee/vault/wrapped';
  // The private key wrapped by the user's 256-bit recovery code. The code is
  // generated on the device and never sent, so what this endpoint stores is
  // ciphertext the server cannot open — which is what keeps messages
  // end-to-end encrypted while still letting a second device catch up.
  static const String chatE2eeRecoveryVault =
      '/api/teams/chat/e2ee/vault/recovery';
  // Device linking: identity, not chat, so it lives outside the independent
  // chat flag and has no /api/teams twin.
  static const String chatE2eeLink = '/api/chat/e2ee/link';
  static const String chatE2eeLinkInfo = '/api/chat/e2ee/link/info';
  static const String chatE2eeLinkApprove = '/api/chat/e2ee/link/approve';
  static const String chatE2eeLinkDeny = '/api/chat/e2ee/link/deny';
  static const String chatE2eeLinkPoll = '/api/chat/e2ee/link/poll';

  /// Conversations where this account holds a key another member lost.
  static const String chatE2eeFillableGaps = '/api/chat/e2ee/gaps';
  // Start fresh: an emailed code buys a brand-new identity for someone with no
  // device left that holds the old one. Path is /api/teams even without a
  // workspace — the identity belongs to the account, not to a team.
  static const String chatE2eeResetCode = '/api/teams/chat/e2ee/reset/code';
  static const String chatE2eeReset = '/api/teams/chat/e2ee/reset';
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

  // Webhook feeds, in both scopes. A workspace feed belongs to a team; a
  // personal one belongs to an account and needs no workspace at all
  // (migration 0128). Which path a feed answers on follows the CONVERSATION's
  // own scope, never the app's independent-chat flag — an account can hold
  // both kinds at once.
  static const String chatWebhookChannels = '/api/teams/chat/webhook-channels';
  static String chatWebhookRegenerate(String conversationId) =>
      '/api/teams/chat/channels/$conversationId/webhook/regenerate';
  static String chatWebhookAvatarPresign(String conversationId) =>
      '/api/teams/chat/channels/$conversationId/webhook/avatar/presign';
  static String chatWebhookAvatar(String conversationId) =>
      '/api/teams/chat/channels/$conversationId/webhook/avatar';

  static const String personalWebhookChannels = '/api/chat/webhook-channels';
  static String personalWebhookRegenerate(String conversationId) =>
      independentChatConversationAction(conversationId, 'webhook/regenerate');
  static String personalWebhookAvatarPresign(String conversationId) =>
      independentChatConversationAction(
        conversationId,
        'webhook/avatar/presign',
      );
  static String personalWebhookAvatar(String conversationId) =>
      independentChatConversationAction(conversationId, 'webhook/avatar');

  // Encrypted history archive. Account-scoped like the E2EE vault, so it sits
  // under /api/messaging rather than under a workspace or the chat flag.
  static const String chatArchive = '/api/messaging/archive';
  static const String chatArchiveBegin = '/api/messaging/archive/begin';
  static const String chatArchiveChunk = '/api/messaging/archive/chunk';
  static const String chatArchiveCommit = '/api/messaging/archive/commit';

  // Phone -> new web/desktop device history transfer. The phone is always the
  // source; listing and acknowledging chunks belong to the destination.
  static const String historyTransfers = '/api/messaging/history-transfers';
  // Live history links (server 0175): phone answers a linked computer over
  // WebRTC instead of uploading to the relay.
  static const String historyLive = '/api/messaging/history-live';
  static const String historyTransferActive =
      '/api/messaging/history-transfers/active';
  static const String historyTransferInfo =
      '/api/messaging/history-transfers/info';
  static const String historyTransferApprove =
      '/api/messaging/history-transfers/approve';
  static const String historyTransferDeny =
      '/api/messaging/history-transfers/deny';

  static const String chatDm = '/api/teams/chat/dm';
  // Calls hang off `/api/chat/*` like the rest of chat: no call belongs to a
  // workspace since the server's migration 0145. The team-prefixed twins stay
  // registered server-side for builds that predate this.
  static String chatVoiceCalls(String conversationId) =>
      '/api/chat/conversations/$conversationId/calls';
  static String chatVoiceCall(String callId) => '/api/chat/calls/$callId';
  static String chatVoiceCallActions(String callId) =>
      '/api/chat/calls/$callId/actions';
  static String chatGroupCall(String conversationId) =>
      '/api/chat/conversations/$conversationId/group-call';
  static String chatGroupCallJoin(String conversationId) =>
      '/api/chat/conversations/$conversationId/group-call/join';
  static String chatGroupCallLeave(String callId) =>
      '/api/chat/group-calls/$callId/leave';
  static String chatGroupCallScreenShare(String callId) =>
      '/api/chat/group-calls/$callId/screen-share';
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
  static String chatConversationPin(String conversationId) =>
      '/api/teams/chat/conversations/$conversationId/pin';
  static String chatConversationHide(String conversationId) =>
      '/api/teams/chat/conversations/$conversationId/hide';
  static String chatConversationAccept(String conversationId) =>
      '/api/teams/chat/conversations/$conversationId/accept';
  static String chatConversationPresign(String conversationId) =>
      '/api/teams/chat/conversations/$conversationId/attachments/presign';
  static String chatConversationDiscard(String conversationId) =>
      '/api/teams/chat/conversations/$conversationId/attachments/discard';
  static String chatConversationMedia(String conversationId) =>
      '/api/teams/chat/conversations/$conversationId/media';
  static String chatConversationReport(String conversationId) =>
      '/api/teams/chat/conversations/$conversationId/report';
  static String chatGroupsInCommon(String userId) =>
      '/api/teams/chat/users/$userId/groups-in-common';
  static const String chatSearch = '/api/teams/chat/search';

  /// Call history. The workspace path lists this workspace's calls; the
  /// independent path lists every call the caller took part in.
  static const String chatCallLog = '/api/teams/chat/calls';

  // Independent chat. Keep all dynamic endpoint construction centralized here.
  static const String independentChatRoot = '/api/chat';
  static const String independentChatConversations =
      '$independentChatRoot/conversations';
  static const String independentChatDm = '$independentChatRoot/dm';
  static const String independentChatGroups = '$independentChatRoot/groups';
  static const String independentChatConnections =
      '$independentChatRoot/connections';
  static const String independentChatConnectionRequests =
      '$independentChatConnections/requests';
  static const String independentChatBlocked =
      '$independentChatConnections/blocked';
  static const String independentChatUsersSearch =
      '$independentChatRoot/users/search';
  static const String independentChatForward = '$independentChatRoot/forward';
  static const String independentChatSearch = '$independentChatRoot/search';
  static const String independentChatCallLog = '$independentChatRoot/calls';
  static String independentChatMessages(String conversationId) =>
      '$independentChatConversations/$conversationId/messages';
  static String independentChatConversation(String conversationId) =>
      '$independentChatConversations/$conversationId';

  /// A suffix under one conversation. An empty [action] would build a
  /// trailing slash, which Gin answers with a 307 redirect instead of the
  /// route — use [independentChatConversation] for the conversation itself.
  static String independentChatConversationAction(
    String conversationId,
    String action,
  ) => action.isEmpty
      ? independentChatConversation(conversationId)
      : '$independentChatConversations/$conversationId/$action';
  // Private chat (server 0160): a phone's pull of what it still owes custody
  // for, and its acknowledgement once those are on disk.
  static const String privateChatPending =
      '$independentChatRoot/private/pending';
  static const String privateChatCustody =
      '$independentChatRoot/private/custody';
  static String independentChatVoiceCalls(String conversationId) =>
      '$independentChatConversations/$conversationId/calls';
  // Ghost Chat: invite, then act on the session. No message endpoint exists —
  // content travels phone to phone and never reaches the server.
  static String ghostChatStart(String conversationId) =>
      '$independentChatConversations/$conversationId/ghost';
  static String ghostChatSession(String sessionId) =>
      '$independentChatRoot/ghost/$sessionId';
  static String ghostChatActions(String sessionId) =>
      '$independentChatRoot/ghost/$sessionId/actions';
  static String independentChatMessage(String messageId) =>
      '$independentChatRoot/messages/$messageId';
  static String independentChatMessageReactions(String messageId) =>
      '${independentChatMessage(messageId)}/reactions';
  static String independentChatGroupsInCommon(String userId) =>
      '$independentChatRoot/users/$userId/groups-in-common';
  static String independentChatE2eePublicKey(String userId) =>
      '$independentChatRoot/e2ee/users/$userId/public-key';
  static String independentChatConnectionRequestAction(
    String requestId,
    String action,
  ) => '$independentChatConnectionRequests/$requestId/$action';
  static String independentChatConnectionUser(String userId) =>
      '$independentChatConnections/$userId';

  // Devices (FCM)
  static const String devices = '/api/devices';

  // Per-device message delivery + key lifecycle.
  static const String messagingDevices = '/api/messaging/devices';
  static String messagingDeviceKey(String deviceId) =>
      '$messagingDevices/${Uri.encodeComponent(deviceId)}/key';
  static const String messagingReceipts = '/api/messaging/receipts';

  // Workspace Cmd+K search (team premium — all members)
  static const String aiSearchMessages = '/api/ai/search-messages';

  // WebSocket
  static const String notificationsStream = '/api/notifications/stream';
  static const String wsAuthSubprotocol = 'ababilx-ws';

  static String get notificationsWsUrl {
    final wsBase = baseUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');
    return '$wsBase$notificationsStream';
  }
}

class StorageKeys {
  StorageKeys._();

  static const String jwt = 'ababilx_jwt';
  static const String refreshToken = 'ababilx_refresh_token';
  static const String fcmToken = 'ababilx_fcm_token';
  static const String messageVaultIdentity = 'ababilx_message_vault_identity';
  static const String messagingDeviceIdentity =
      'ababilx_messaging_device_identity';
  static const String localDataOwnerUserId = 'ababilx_local_data_owner_user_id';

  /// Ed25519 seed of a key-only account ("Start New Chat"). The account's
  /// only credential: deleted on sign-out, and with it the account.
  static const String accountKey = 'account_key_v1';
}
