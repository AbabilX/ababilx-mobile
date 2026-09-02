import 'package:equatable/equatable.dart';

import 'chat_attachment.dart';
import 'chat_delivery_summary.dart';
import 'chat_reaction.dart';

/// Send-state for optimistic messages. Server-confirmed messages are [sent].
/// [sending] = in-flight, [failed] = network/server error, user can retry.
enum MessageSendStatus { sent, sending, failed }

class ChatMessage extends Equatable {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.userId,
    required this.body,
    this.parentId,
    required this.createdAt,
    this.editedAt,
    this.deletedAt,
    this.userName,
    this.userAvatarUrl,
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
    // Optimistic-send fields — not present in server JSON.
    this.sendStatus = MessageSendStatus.sent,
    this.clientRef,
    this.pendingAttachments = const [],
    this.pendingParentId,
    this.pendingMentionedUserIds = const [],
  });

  final String id;
  final String conversationId;
  final String userId;
  final String body;
  final String? parentId;
  final String createdAt;
  final String? editedAt;
  final String? deletedAt;
  final String? userName;
  final String? userAvatarUrl;
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

  /// Optimistic UI: current send state.
  final MessageSendStatus sendStatus;

  /// Stable sender-generated ID used to match a pending send, HTTP response,
  /// and WebSocket event. New server-confirmed messages preserve it.
  final String? clientRef;

  /// Pending data kept only until server confirms — not serialised to cache.
  final List<ChatAttachmentInput> pendingAttachments;
  final String? pendingParentId;
  final List<String> pendingMentionedUserIds;

  bool get isDeleted => deletedAt != null;
  bool get isSystem => messageType == 'system';
  bool get isVoiceCall => messageType == 'voice_call';
  bool get isGroupCall => messageType == 'group_call';
  bool get isPending => sendStatus != MessageSendStatus.sent;
  bool get isEncrypted => encryptionVersion == 1 && encryptedBody != null;

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'] as String? ?? '',
    conversationId: json['conversation_id'] as String? ?? '',
    userId: json['user_id'] as String? ?? '',
    body: json['body'] as String? ?? '',
    parentId: json['parent_id'] as String?,
    createdAt: json['created_at'] as String? ?? '',
    editedAt: json['edited_at'] as String?,
    deletedAt: json['deleted_at'] as String?,
    userName: json['user_name'] as String?,
    userAvatarUrl: json['user_avatar_url'] as String?,
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
    clientRef: json['client_message_id'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'conversation_id': conversationId,
    'user_id': userId,
    'body': body,
    if (parentId != null) 'parent_id': parentId,
    'created_at': createdAt,
    if (editedAt != null) 'edited_at': editedAt,
    if (deletedAt != null) 'deleted_at': deletedAt,
    if (userName != null) 'user_name': userName,
    if (userAvatarUrl != null) 'user_avatar_url': userAvatarUrl,
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
    if (clientRef != null) 'client_message_id': clientRef,
    // Pending fields deliberately excluded from cache serialisation.
  };

  ChatMessage copyWith({
    String? id,
    String? body,
    String? editedAt,
    String? deletedAt,
    List<ChatReactionGroup>? reactions,
    int? threadCount,
    MessageSendStatus? sendStatus,
    String? clientRef,
    bool clearClientRef = false,
    ChatDeliverySummary? delivery,
  }) => ChatMessage(
    id: id ?? this.id,
    conversationId: conversationId,
    userId: userId,
    body: body ?? this.body,
    parentId: parentId,
    createdAt: createdAt,
    editedAt: editedAt ?? this.editedAt,
    deletedAt: deletedAt ?? this.deletedAt,
    userName: userName,
    userAvatarUrl: userAvatarUrl,
    attachments: attachments,
    reactions: reactions ?? this.reactions,
    threadCount: threadCount ?? this.threadCount,
    viaAbabilx: viaAbabilx,
    messageType: messageType,
    meta: meta,
    forwardedFromName: forwardedFromName,
    forwardedFromSource: forwardedFromSource,
    encryptedBody: encryptedBody,
    encryptionNonce: encryptionNonce,
    encryptionVersion: encryptionVersion,
    encryptionKeyVersion: encryptionKeyVersion,
    delivery: delivery ?? this.delivery,
    sendStatus: sendStatus ?? this.sendStatus,
    clientRef: clearClientRef ? null : (clientRef ?? this.clientRef),
    pendingAttachments: pendingAttachments,
    pendingParentId: pendingParentId,
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
    delivery,
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
