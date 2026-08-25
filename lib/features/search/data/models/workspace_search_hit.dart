import 'package:equatable/equatable.dart';

/// Hit from `GET /api/ai/search-messages` (web Cmd+K).
class WorkspaceSearchHit extends Equatable {
  const WorkspaceSearchHit({
    required this.source,
    this.conversationId,
    this.messageId,
    this.anchorId,
    this.postId,
    this.taskId,
    this.boardId,
    this.label = '',
    this.authorName = '',
    this.snippet = '',
    this.createdAt = '',
  });

  final String source;
  final String? conversationId;
  final String? messageId;
  final String? anchorId;
  final String? postId;
  final String? taskId;
  final String? boardId;
  final String label;
  final String authorName;
  final String snippet;
  final String createdAt;

  factory WorkspaceSearchHit.fromJson(Map<String, dynamic> json) =>
      WorkspaceSearchHit(
        source: json['source'] as String? ?? '',
        conversationId: json['conversation_id'] as String?,
        messageId: json['message_id'] as String?,
        anchorId: json['anchor_id'] as String?,
        postId: json['post_id'] as String?,
        taskId: json['task_id'] as String?,
        boardId: json['board_id'] as String?,
        label: json['label'] as String? ?? '',
        authorName: json['author_name'] as String? ?? '',
        snippet: json['snippet'] as String? ?? '',
        createdAt: json['created_at'] as String? ?? '',
      );

  String get typeBadge => switch (source) {
    'dm' => 'DM',
    'channel' => 'Channel',
    'wall_post' => 'Wall',
    'wall_comment' => 'Wall reply',
    'task' => 'Task',
    'task_comment' => 'Task comment',
    _ => source,
  };

  String get title {
    if (source == 'channel' && label.isNotEmpty) return '#$label';
    if (label.isNotEmpty) return label;
    if (authorName.isNotEmpty) return authorName;
    return typeBadge;
  }

  @override
  List<Object?> get props => [
    source,
    conversationId,
    messageId,
    postId,
    taskId,
  ];
}
