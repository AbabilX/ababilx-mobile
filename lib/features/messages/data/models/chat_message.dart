import 'package:equatable/equatable.dart';

import 'chat_attachment.dart';
import 'chat_delivery_summary.dart';
import 'chat_message_quote.dart';
import 'chat_reaction.dart';

/// Send-state for optimistic messages. Server-confirmed messages are [sent].
/// [sending] = in-flight, [failed] = network/server error, user can retry.
enum MessageSendStatus { sent, uploading, sending, failed }

class ChatMessage extends Equatable {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.userId,
    required this.body,
    this.parentId,
    this.revision = 0,
    this.contentPurged = false,
    this.privateChat = false,
    required this.createdAt,
    this.editedAt,
    this.deletedAt,
    this.userName,
    this.userAvatarUrl,
    this.senderTag,
    this.attachments = const [],
    this.reactions = const [],
    this.threadCount = 0,
    this.viaAbabilx = false,
    this.messageType = 'text',
    this.meta,
    this.forwardedFromName,
    this.forwardedFromSource,
    this.encryptedBody,
    this.encryptionNonce,
    this.encryptionVersion,
    this.encryptionKeyVersion,
    this.delivery,
    this.quote,
    // Optimistic-send fields — not present in server JSON.
    this.sendStatus = MessageSendStatus.sent,
    this.uploadProgress,
    this.clientRef,
    this.pendingAttachments = const [],
    this.pendingParentId,
    this.pendingQuotedMessageId,
    this.pendingMentionedUserIds = const [],
  });

  final String id;
  final String conversationId;
  final String userId;
  final String body;
  final String? parentId;
  final int revision;
  final bool contentPurged;

  /// Sent while private chat was on (server 0160). The server drops it once
  /// the recipient's phones have it, so this phone's copy is the only one:
  /// never saved out, shared or forwarded, edits / reactions / deletes travel
  /// as private ops, and replies are quotes resolved from local history.
  final bool privateChat;
  final String createdAt;
  final String? editedAt;
  final String? deletedAt;
  final String? userName;
  final String? userAvatarUrl;

  /// The author's group member tag as the server read it with this page
  /// (0157). A live change arrives on `chat.member.updated` and wins over
  /// this — see `groupMemberTagsProvider`.
  final String? senderTag;
  final List<ChatMessageAttachment> attachments;
  final List<ChatReactionGroup> reactions;
  final int threadCount;
  final bool viaAbabilx;
  final String messageType;
  final Map<String, dynamic>? meta;
  final String? forwardedFromName;
  final String? forwardedFromSource;
  final String? encryptedBody;
  final String? encryptionNonce;
  final int? encryptionVersion;
  final int? encryptionKeyVersion;
  final ChatDeliverySummary? delivery;

  /// The message this one quotes, if any. A quoted reply stays in the main
  /// timeline; [parentId] is the separate, Slack-style thread reply.
  final ChatMessageQuote? quote;

  /// Optimistic UI: current send state.
  final MessageSendStatus sendStatus;

  /// Transient aggregate progress for this device's active attachment upload.
  /// It is deliberately not persisted; interrupted uploads reopen as failed.
  final double? uploadProgress;

  /// Stable sender-generated ID used to match a pending send, HTTP response,
  /// and WebSocket event. New server-confirmed messages preserve it.
  final String? clientRef;

  /// Retry payload kept on unsent local rows so a killed send can resume.
  final List<ChatAttachmentInput> pendingAttachments;
  final String? pendingParentId;
  final String? pendingQuotedMessageId;
  final List<String> pendingMentionedUserIds;

  bool get isDeleted => deletedAt != null;

  /// Carries a photo or file its sender restricted in privacy mode (a timer
  /// or no saving): never saved, shared, or forwarded by anyone else.
  bool get hasProtectedMedia => attachments.any((a) => a.isProtected);
  bool get isSystem => messageType == 'system';
  bool get isVoiceCall => messageType == 'voice_call';

  /// Posted by an inbound webhook, so it has no sender: [userId] is empty and
  /// [userName] null. The display name comes from the feed, via
  /// [webhookSourceName], and the avatar arrives in [userAvatarUrl] — the
  /// server joins the webhook's own picture into that column.
  bool get isWebhook => messageType == 'webhook';

  String? get webhookSourceName {
    final source = meta?['source_name'];
    if (source is! String) return null;
    final trimmed = source.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  bool get isGroupCall => messageType == 'group_call';

  /// The message a private-chat reply quotes, by id only (server 0160). The
  /// quoted message may already be gone from the server, so the phone looks
  /// it up in its own history — see `resolvePrivateQuote`.
  String? get privateQuoteId {
    final id = meta?['private_quote_id'];
    return id is String && id.isNotEmpty ? id : null;
  }

  bool get isPending => sendStatus != MessageSendStatus.sent;
  bool get isEncrypted => encryptionVersion == 1 && encryptedBody != null;

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'] as String? ?? '',
    conversationId: json['conversation_id'] as String? ?? '',
    userId: json['user_id'] as String? ?? '',
    body: json['body'] as String? ?? '',
    parentId: json['parent_id'] as String?,
    revision: (json['revision'] as num?)?.toInt() ?? 0,
    contentPurged: json['content_purged'] == true,
    privateChat: json['private_chat'] == true,
    createdAt: json['created_at'] as String? ?? '',
    editedAt: json['edited_at'] as String?,
    deletedAt: json['deleted_at'] as String?,
    userName: json['user_name'] as String?,
    userAvatarUrl: json['user_avatar_url'] as String?,
    senderTag: json['sender_tag'] as String?,
    attachments: (json['attachments'] as List<dynamic>? ?? [])
        .map((e) => ChatMessageAttachment.fromJson(e as Map<String, dynamic>))
        .toList(),
    reactions: (json['reactions'] as List<dynamic>? ?? [])
        .map((e) => ChatReactionGroup.fromJson(e as Map<String, dynamic>))
        .toList(),
    threadCount: json['thread_count'] as int? ?? 0,
    viaAbabilx: json['via_ababilx'] as bool? ?? false,
    messageType: json['message_type'] as String? ?? 'text',
    meta: json['meta'] is Map
        ? Map<String, dynamic>.from(json['meta'] as Map)
        : null,
    forwardedFromName: json['forwarded_from_name'] as String?,
    forwardedFromSource: json['forwarded_from_source'] as String?,
    encryptedBody: json['encrypted_body'] as String?,
    encryptionNonce: json['encryption_nonce'] as String?,
    encryptionVersion: (json['encryption_version'] as num?)?.toInt(),
    encryptionKeyVersion: (json['encryption_key_version'] as num?)?.toInt(),
    delivery: json['delivery'] is Map
        ? ChatDeliverySummary.fromJson(
            Map<String, dynamic>.from(json['delivery'] as Map),
          )
        : null,
    quote: json['quote'] is Map
        ? ChatMessageQuote.fromJson(
            Map<String, dynamic>.from(json['quote'] as Map),
          )
        : null,
    sendStatus: _sendStatusFromJson(json['send_status']),
    clientRef: json['client_message_id'] as String?,
    pendingAttachments: (json['pending_attachments'] as List<dynamic>? ?? [])
        .map((e) => ChatAttachmentInput.fromJson(e as Map<String, dynamic>))
        .toList(),
    pendingParentId: json['pending_parent_id'] as String?,
    pendingQuotedMessageId: json['pending_quoted_message_id'] as String?,
    pendingMentionedUserIds:
        (json['pending_mentioned_user_ids'] as List<dynamic>? ?? [])
            .cast<String>(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'revision': revision,
    'content_purged': contentPurged,
    if (privateChat) 'private_chat': true,
    'conversation_id': conversationId,
    'user_id': userId,
    'body': body,
    if (parentId != null) 'parent_id': parentId,
    'created_at': createdAt,
    if (editedAt != null) 'edited_at': editedAt,
    if (deletedAt != null) 'deleted_at': deletedAt,
    if (userName != null) 'user_name': userName,
    if (userAvatarUrl != null) 'user_avatar_url': userAvatarUrl,
    if (senderTag != null) 'sender_tag': senderTag,
    'attachments': attachments.map((a) => a.toJson()).toList(),
    'reactions': reactions.map((r) => r.toJson()).toList(),
    'thread_count': threadCount,
    'via_ababilx': viaAbabilx,
    'message_type': messageType,
    if (meta != null) 'meta': meta,
    if (forwardedFromName != null) 'forwarded_from_name': forwardedFromName,
    if (forwardedFromSource != null)
      'forwarded_from_source': forwardedFromSource,
    if (encryptedBody != null) 'encrypted_body': encryptedBody,
    if (encryptionNonce != null) 'encryption_nonce': encryptionNonce,
    if (encryptionVersion != null) 'encryption_version': encryptionVersion,
    if (encryptionKeyVersion != null)
      'encryption_key_version': encryptionKeyVersion,
    if (delivery != null) 'delivery': delivery!.toJson(),
    if (quote != null) 'quote': quote!.toJson(),
    if (clientRef != null) 'client_message_id': clientRef,
    if (sendStatus != MessageSendStatus.sent) 'send_status': sendStatus.name,
    if (pendingAttachments.isNotEmpty)
      'pending_attachments': pendingAttachments.map((a) => a.toJson()).toList(),
    if (pendingParentId != null) 'pending_parent_id': pendingParentId,
    if (pendingQuotedMessageId != null)
      'pending_quoted_message_id': pendingQuotedMessageId,
    if (pendingMentionedUserIds.isNotEmpty)
      'pending_mentioned_user_ids': pendingMentionedUserIds,
  };

  ChatMessage copyWith({
    String? id,
    String? body,
    String? editedAt,
    String? deletedAt,
    List<ChatReactionGroup>? reactions,
    int? threadCount,
    MessageSendStatus? sendStatus,
    double? uploadProgress,
    bool clearUploadProgress = false,
    List<ChatAttachmentInput>? pendingAttachments,
    String? clientRef,
    bool clearClientRef = false,
    ChatDeliverySummary? delivery,
    String? encryptedBody,
    String? encryptionNonce,
    int? encryptionVersion,
    int? encryptionKeyVersion,
    ChatMessageQuote? quote,
    bool? privateChat,
    List<ChatMessageAttachment>? attachments,
  }) => ChatMessage(
    id: id ?? this.id,
    conversationId: conversationId,
    userId: userId,
    body: body ?? this.body,
    parentId: parentId,
    revision: revision,
    contentPurged: contentPurged,
    privateChat: privateChat ?? this.privateChat,
    createdAt: createdAt,
    editedAt: editedAt ?? this.editedAt,
    deletedAt: deletedAt ?? this.deletedAt,
    userName: userName,
    userAvatarUrl: userAvatarUrl,
    senderTag: senderTag,
    attachments: attachments ?? this.attachments,
    reactions: reactions ?? this.reactions,
    threadCount: threadCount ?? this.threadCount,
    viaAbabilx: viaAbabilx,
    messageType: messageType,
    meta: meta,
    forwardedFromName: forwardedFromName,
    forwardedFromSource: forwardedFromSource,
    encryptedBody: encryptedBody ?? this.encryptedBody,
    encryptionNonce: encryptionNonce ?? this.encryptionNonce,
    encryptionVersion: encryptionVersion ?? this.encryptionVersion,
    encryptionKeyVersion: encryptionKeyVersion ?? this.encryptionKeyVersion,
    delivery: delivery ?? this.delivery,
    quote: quote ?? this.quote,
    sendStatus: sendStatus ?? this.sendStatus,
    uploadProgress: clearUploadProgress
        ? null
        : (uploadProgress ?? this.uploadProgress),
    clientRef: clearClientRef ? null : (clientRef ?? this.clientRef),
    pendingAttachments: pendingAttachments ?? this.pendingAttachments,
    pendingParentId: pendingParentId,
    pendingQuotedMessageId: pendingQuotedMessageId,
    pendingMentionedUserIds: pendingMentionedUserIds,
  );

  @override
  List<Object?> get props => [
    id,
    body,
    editedAt,
    deletedAt,
    reactions,
    threadCount,
    sendStatus,
    uploadProgress,
    delivery,
    quote,
    privateChat,
  ];
}

class ChatMessagesPage extends Equatable {
  const ChatMessagesPage({
    required this.messages,
    required this.nextCursor,
    required this.hasMore,
  });

  final List<ChatMessage> messages;
  final String nextCursor;
  final bool hasMore;

  factory ChatMessagesPage.fromJson(Map<String, dynamic> json) =>
      ChatMessagesPage(
        messages: (json['messages'] as List<dynamic>? ?? [])
            .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
            .toList(),
        nextCursor: json['next_cursor'] as String? ?? '',
        hasMore: json['has_more'] as bool? ?? false,
      );

  @override
  List<Object?> get props => [messages.length, nextCursor, hasMore];
}

MessageSendStatus _sendStatusFromJson(Object? raw) {
  if (raw is! String) return MessageSendStatus.sent;
  return switch (raw) {
    'sending' => MessageSendStatus.sending,
    'uploading' => MessageSendStatus.uploading,
    'failed' => MessageSendStatus.failed,
    _ => MessageSendStatus.sent,
  };
}
