import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import 'chat_attachments_api.dart';
import 'chat_conversations_api.dart';
import 'chat_messages_api.dart';
import 'models/chat_models.dart';

class ChatRepository {
  ChatRepository(ApiClient client)
    : _conversations = ChatConversationsApi(client),
      _messages = ChatMessagesApi(client),
      _attachments = ChatAttachmentsApi(client);

  final ChatConversationsApi _conversations;
  final ChatMessagesApi _messages;
  final ChatAttachmentsApi _attachments;

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

  Future<void> leaveChannel(String channelId) =>
      _conversations.leaveChannel(channelId);

  Future<void> deleteChannel(String channelId) =>
      _conversations.deleteChannel(channelId);

  Future<ChatConversation> startDm(String userId) =>
      _conversations.startDm(userId);

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
    required String body,
    String? parentId,
    List<ChatAttachmentInput> attachments = const [],
    List<String> mentionedUserIds = const [],
  }) => _messages.sendMessage(
    conversationId,
    body: body,
    parentId: parentId,
    attachments: attachments,
    mentionedUserIds: mentionedUserIds,
  );

  Future<ChatMessage> patchMessage(String messageId, String body) =>
      _messages.patchMessage(messageId, body);

  Future<void> deleteMessage(String messageId) =>
      _messages.deleteMessage(messageId);

  Future<List<ChatReactionGroup>> toggleReaction(
    String messageId,
    String emoji,
  ) => _messages.toggleReaction(messageId, emoji);

  Future<void> markRead(String conversationId) =>
      _messages.markRead(conversationId);

  Future<bool> muteConversation(String conversationId, bool muted) =>
      _conversations.muteConversation(conversationId, muted);

  Future<void> hideDm(String conversationId) =>
      _conversations.hideDm(conversationId);

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

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => ChatRepository(ref.watch(apiClientProvider)),
);
