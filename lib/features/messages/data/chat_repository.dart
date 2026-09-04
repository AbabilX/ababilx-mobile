import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import 'chat_attachments_api.dart';
import 'chat_connections_api.dart';
import 'chat_device_repository.dart';
import 'chat_endpoints.dart';
import 'chat_e2ee_api.dart';
import 'chat_conversations_api.dart';
import 'chat_messages_api.dart';
import 'models/chat_models.dart';
import '../../profile/providers/profile_provider.dart';

class ChatRepository {
  ChatRepository(ApiClient client, {bool independent = false})
    : _conversations = ChatConversationsApi(
        client,
        ChatEndpoints(independent: independent),
      ),
      _messages = ChatMessagesApi(
        client,
        ChatEndpoints(independent: independent),
      ),
      _e2ee = ChatE2eeApi(client, ChatEndpoints(independent: independent)),
      _attachments = ChatAttachmentsApi(
        client,
        ChatEndpoints(independent: independent),
      ),
      _devices = ChatDeviceRepository(client),
      _connections = ChatConnectionsApi(client);

  final ChatConversationsApi _conversations;
  final ChatMessagesApi _messages;
  final ChatE2eeApi _e2ee;
  final ChatAttachmentsApi _attachments;
  final ChatDeviceRepository _devices;
  final ChatConnectionsApi _connections;

  Future<ChatSidebar> listConversations() => _conversations.listConversations();

  Future<ChatConversation> createChannel({
    required String name,
    String? slug,
    bool isPrivate = false,
  }) => _conversations.createChannel(
    name: name,
    slug: slug,
    isPrivate: isPrivate,
  );

  Future<ChatConversation> patchChannel(
    String id, {
    String? name,
    bool? archive,
  }) => _conversations.patchChannel(id, name: name, archive: archive);

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
  Future<List<ChatConnection>> listConnections() =>
      _connections.listConnections();
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
    String? caption,
  }) => _conversations.forwardMessage(
    messageId: messageId,
    conversationIds: conversationIds,
    userIds: userIds,
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

  Future<Map<String, dynamic>> getE2eeVault() => _e2ee.getVault();
  Future<void> putE2eeVault(Map<String, dynamic> data) => _e2ee.putVault(data);
  Future<void> putE2eeIdentity(Map<String, dynamic> publicJwk) =>
      _e2ee.putIdentity(publicJwk);
  Future<void> deleteE2eeWrappedKey() => _e2ee.deleteWrappedKey();
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
  Future<Map<String, dynamic>> createE2eeConversationKey(
    String conversationId,
    Map<String, dynamic> envelopes,
  ) => _e2ee.createConversationKey(conversationId, envelopes);

  Future<bool> muteConversation(String conversationId, bool muted) =>
      _conversations.muteConversation(conversationId, muted);

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
  }) => _attachments.presignAttachment(
    conversationId,
    contentType: contentType,
    fileName: fileName,
    sizeBytes: sizeBytes,
  );

  Future<void> discardUpload(String conversationId, String fileUrl) =>
      _attachments.discardUpload(conversationId, fileUrl);
}

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final independent =
      ref.watch(profileProvider).valueOrNull?.independentChat ?? false;
  return ChatRepository(ref.watch(apiClientProvider), independent: independent);
});
