import 'package:equatable/equatable.dart';

import 'chat_attachment.dart';
import 'chat_reaction.dart';

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
    this.forwardedFromName,
    this.forwardedFromSource,
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
  final String? forwardedFromName;
  final String? forwardedFromSource;

  bool get isDeleted => deletedAt != null;
  bool get isSystem => messageType == 'system';

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
            .map((e) =>
                ChatMessageAttachment.fromJson(e as Map<String, dynamic>))
            .toList(),
        reactions: (json['reactions'] as List<dynamic>? ?? [])
            .map((e) => ChatReactionGroup.fromJson(e as Map<String, dynamic>))
            .toList(),
        threadCount: json['thread_count'] as int? ?? 0,
        viaAbabilx: json['via_ababilx'] as bool? ?? false,
        messageType: json['message_type'] as String? ?? 'text',
        forwardedFromName: json['forwarded_from_name'] as String?,
        forwardedFromSource: json['forwarded_from_source'] as String?,
      );

  ChatMessage copyWith({
    String? body,
    String? editedAt,
    String? deletedAt,
    List<ChatReactionGroup>? reactions,
    int? threadCount,
  }) =>
      ChatMessage(
        id: id,
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
        forwardedFromName: forwardedFromName,
        forwardedFromSource: forwardedFromSource,
      );

  @override
  List<Object?> get props => [id, body, editedAt, deletedAt, reactions, threadCount];
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
