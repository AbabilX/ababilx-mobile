import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import 'chat_attachments_api.dart';
import 'chat_connections_api.dart';
import 'chat_device_repository.dart';
import 'chat_endpoints.dart';
import 'chat_e2ee_api.dart';
import 'chat_e2ee_history_api.dart';
import '../chat-mute/mute_choice.dart';
import 'chat_conversations_api.dart';
import 'chat_messages_api.dart';
import 'chat_webhooks_api.dart';
import 'models/chat_models.dart';

class ChatRepository {
  ChatRepository(ApiClient client)
    : _conversations = ChatConversationsApi(client, const ChatEndpoints()),
      _messages = ChatMessagesApi(client, const ChatEndpoints()),
      _e2ee = ChatE2eeApi(client, const ChatEndpoints()),
      _e2eeHistory = ChatE2eeHistoryApi(client, const ChatEndpoints()),
      _attachments = ChatAttachmentsApi(client, const ChatEndpoints()),
      _devices = ChatDeviceRepository(client),
      _connections = ChatConnectionsApi(client),
      _webhooks = ChatWebhooksApi(client);

  final ChatConversationsApi _conversations;
  final ChatMessagesApi _messages;
  final ChatE2eeApi _e2ee;
  final ChatE2eeHistoryApi _e2eeHistory;
  final ChatAttachmentsApi _attachments;
  final ChatDeviceRepository _devices;
  final ChatConnectionsApi _connections;
  final ChatWebhooksApi _webhooks;

  Future<List<ChatPinnedMessage>> pinnedMessages(String conversationId) =>
      _messages.pinnedMessages(conversationId);

  Future<void> setMessagePinned(
    String conversationId,
    String messageId, {
    required bool pinned,
  }) => _messages.setMessagePinned(conversationId, messageId, pinned: pinned);

  Future<ChatSidebar> listConversations() => _conversations.listConversations();

  /// A webhook feed is an ordinary group in every way except that nobody may
  /// post into it, so it is created here and then managed through the same
  /// conversation calls above.
  Future<({ChatConversation conversation, ChatWebhookCreated created})>
  createWebhookChannel({required String name}) =>
      _webhooks.createWebhookChannel(name: name);

  Future<ChatWebhookCreated> regenerateWebhook(String conversationId) =>
      _webhooks.regenerate(conversationId);

  Future<ChatPresignResult> presignWebhookAvatar(
    String conversationId, {
    required String contentType,
    required int sizeBytes,
  }) => _webhooks.presignAvatar(
    conversationId,
    contentType: contentType,
    sizeBytes: sizeBytes,
  );

  Future<String> saveWebhookAvatar(String conversationId, String avatarUrl) =>
      _webhooks.saveAvatar(conversationId, avatarUrl);

  Future<void> addChannelMember(String channelId, String userId) =>
      _conversations.addChannelMember(channelId, userId);

  Future<List<ChatMember>> listChannelMembers(String channelId) =>
      _conversations.listChannelMembers(channelId);

  Future<ChatConversation> updateGroupInfo(
    String id, {
    String? name,
    String? description,
    String? avatarUrl,
    String? bannerUrl,
  }) => _conversations.updateGroupInfo(
    id,
    name: name,
    description: description,
    avatarUrl: avatarUrl,
    bannerUrl: bannerUrl,
  );

  Future<void> setGroupMemberRole(String id, String userId, String role) =>
      _conversations.setGroupMemberRole(id, userId, role);

  Future<void> removeGroupMember(String id, String userId) =>
      _conversations.removeGroupMember(id, userId);

  Future<void> leaveChannel(String channelId) =>
      _conversations.leaveChannel(channelId);

  Future<void> deleteChannel(String channelId) =>
      _conversations.deleteChannel(channelId);

  Future<ChatConversation> startDm(String userId) =>
      _conversations.startDm(userId);

  Future<ChatConversation> createPersonalGroup(
    String name,
    List<String> memberIds,
  ) => _conversations.createPersonalGroup(name, memberIds);

  Future<ChatUserSearchResult> searchUsers(String query) =>
      _connections.search(query);
  Future<ChatUserSummary?> lookupUserByUsername(String username) =>
      _connections.lookupByUsername(username);
  Future<List<ChatConnection>> listConnections() =>
      _connections.listConnections();
  Future<List<ChatConnection>> listBlockedUsers() => _connections.listBlocked();
  Future<ChatConnectionRequests> listConnectionRequests() =>
      _connections.listRequests();
  Future<void> sendConnectionRequest(String userId) =>
      _connections.sendRequest(userId);
  Future<void> respondConnectionRequest(String id, {required bool accept}) =>
      _connections.respond(id, accept: accept);
  Future<void> blockUser(String userId) => _connections.block(userId);
  Future<void> removeConnection(String userId) => _connections.remove(userId);

  Future<int> forwardMessage({
    required String messageId,
    List<String>? conversationIds,
    List<String>? userIds,
    List<Map<String, dynamic>>? targets,
    String? caption,
  }) => _conversations.forwardMessage(
    messageId: messageId,
    conversationIds: conversationIds,
    userIds: userIds,
    targets: targets,
    caption: caption,
  );

  Future<ChatMessagesPage> listMessages(
    String conversationId, {
    String? cursor,
    int? limit,
    String? thread,
  }) => _messages.listMessages(
    conversationId,
    cursor: cursor,
    limit: limit,
    thread: thread,
  );

  Future<ChatMessage> sendMessage(
    String conversationId, {
    required String clientMessageId,
    required String body,
    String? encryptedBody,
    String? encryptionNonce,
    int? encryptionVersion,
    int? encryptionKeyVersion,
    String? parentId,
    String? quotedMessageId,
    List<ChatAttachmentInput> attachments = const [],
    List<String> mentionedUserIds = const [],
  }) => _messages.sendMessage(
    conversationId,
    clientMessageId: clientMessageId,
    body: body,
    encryptedBody: encryptedBody,
    encryptionNonce: encryptionNonce,
    encryptionVersion: encryptionVersion,
    encryptionKeyVersion: encryptionKeyVersion,
    parentId: parentId,
    quotedMessageId: quotedMessageId,
    attachments: attachments,
    mentionedUserIds: mentionedUserIds,
  );

  Future<ChatMessage> patchMessage(
    String messageId,
    String body, {
    String? encryptedBody,
    String? encryptionNonce,
    int? encryptionVersion,
    int? encryptionKeyVersion,
  }) => _messages.patchMessage(
    messageId,
    body,
    encryptedBody: encryptedBody,
    encryptionNonce: encryptionNonce,
    encryptionVersion: encryptionVersion,
    encryptionKeyVersion: encryptionKeyVersion,
  );

  Future<void> deleteMessage(String messageId) =>
      _messages.deleteMessage(messageId);

  Future<void> hideMessage(String messageId) =>
      _messages.hideMessage(messageId);

  Future<Map<String, TimedMediaGrant>> markMediaViewed(String messageId) =>
      _messages.markMediaViewed(messageId);

  Future<List<ChatReactionGroup>> toggleReaction(
    String messageId,
    String emoji,
  ) => _messages.toggleReaction(messageId, emoji);

  Future<void> markRead(String conversationId) =>
      _messages.markRead(conversationId);

  Future<void> ensureMessagingDevice() async {
    await _devices.ensureRegistered();
  }

  Future<void> acknowledgeMessages(String status, List<String> messageIds) =>
      _devices.acknowledge(status, messageIds);

  /// This phone's messaging device id, registering it first if needed.
  Future<String> chatDeviceId() async =>
      (await _devices.ensureRegistered()).deviceId;

  Future<Map<String, dynamic>> getE2eeVault() => _e2ee.getVault();
  Future<void> putE2eeVault(Map<String, dynamic> data) => _e2ee.putVault(data);
  Future<void> putE2eeIdentity(Map<String, dynamic> publicJwk) =>
      _e2ee.putIdentity(publicJwk);
  Future<void> deleteE2eeWrappedKey() => _e2ee.deleteWrappedKey();
  Future<void> putE2eeRecoveryVault(
    Map<String, dynamic> publicJwk,
    Map<String, dynamic> recovery,
  ) => _e2ee.putRecoveryVault(publicJwk, recovery);
  Future<Map<String, dynamic>> requestE2eeResetCode() =>
      _e2ee.requestResetCode();
  Future<void> resetE2eeVault(
    String code,
    Map<String, dynamic> publicJwk,
    Map<String, dynamic> recovery,
  ) => _e2ee.resetVault(code, publicJwk, recovery);
  Future<Map<String, dynamic>> createE2eeLink(String deviceName) =>
      _e2ee.createLink(deviceName);
  Future<Map<String, dynamic>> inspectE2eeLink(String token) =>
      _e2ee.inspectLink(token);
  Future<void> approveE2eeLink(String token, Map<String, dynamic> envelope) =>
      _e2ee.approveLink(token, envelope);
  Future<void> denyE2eeLink(String token) => _e2ee.denyLink(token);
  Future<Map<String, dynamic>> pollE2eeLink(String token) =>
      _e2ee.pollLink(token);
  Future<Map<String, dynamic>> getE2eePublicKey(String userId) =>
      _e2ee.getPublicKey(userId);
  Future<Map<String, dynamic>> getE2eeConversationKey(String conversationId) =>
      _e2ee.getConversationKey(conversationId);
  Future<Map<String, dynamic>> getE2eeConversationKeyVersions(
    String conversationId,
    List<int> versions,
  ) => _e2eeHistory.getConversationKeyVersions(conversationId, versions);
  Future<Map<String, dynamic>> reportUnreadableE2eeEnvelope(
    String conversationId,
    int keyVersion,
    Map<String, dynamic> publicJwk,
  ) => _e2eeHistory.reportUnreadableEnvelope(
    conversationId,
    keyVersion,
    publicJwk,
  );
  Future<Map<String, dynamic>> getE2eeFillableGaps() =>
      _e2eeHistory.getFillableGaps();
  Future<Map<String, dynamic>> getE2eeConversationMembers(
    String conversationId,
  ) => _e2ee.getConversationMembers(conversationId);

  Future<Map<String, dynamic>> createE2eeConversationKey(
    String conversationId,
    Map<String, dynamic> envelopes,
  ) => _e2ee.createConversationKey(conversationId, envelopes);
  Future<Map<String, dynamic>> backfillE2eeConversationKey(
    String conversationId,
    List<Map<String, dynamic>> envelopes,
  ) => _e2ee.backfillConversationKey(conversationId, envelopes);

  Future<MuteResult> setMute(String conversationId, MuteChoice? choice) =>
      _conversations.setMute(conversationId, choice);

  Future<bool> pinConversation(String conversationId, bool pinned) =>
      _conversations.pinConversation(conversationId, pinned);

  Future<void> hideDm(String conversationId) =>
      _conversations.hideDm(conversationId);

  Future<void> acceptMessageRequest(String conversationId) =>
      _conversations.acceptMessageRequest(conversationId);

  Future<List<ChatMessage>> searchMessages(String q, {int limit = 20}) =>
      _messages.searchMessages(q, limit: limit);

  Future<ChatPresignResult> presignAttachment(
    String conversationId, {
    required String contentType,
    required String fileName,
    required int sizeBytes,
    bool encrypted = false,
  }) => _attachments.presignAttachment(
    conversationId,
    contentType: contentType,
    fileName: fileName,
    sizeBytes: sizeBytes,
    encrypted: encrypted,
  );

  Future<void> discardUpload(String conversationId, String fileUrl) =>
      _attachments.discardUpload(conversationId, fileUrl);
}

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(ref.watch(apiClientProvider));
});
