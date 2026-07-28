import 'package:equatable/equatable.dart';

class KanbanBoard extends Equatable {
  const KanbanBoard({
    required this.id,
    required this.teamId,
    required this.name,
    required this.createdBy,
    required this.createdAt,
    this.memberIds = const [],
    this.columns = const [],
  });

  final String id;
  final String teamId;
  final String name;
  final String createdBy;
  final String createdAt;
  final List<String> memberIds;
  final List<KanbanColumn> columns;

  factory KanbanBoard.fromJson(Map<String, dynamic> json) => KanbanBoard(
        id: json['id'] as String,
        teamId: json['team_id'] as String,
        name: json['name'] as String? ?? 'Board',
        createdBy: json['created_by'] as String? ?? '',
        createdAt: json['created_at'] as String? ?? '',
        memberIds: (json['member_ids'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        columns: (json['columns'] as List<dynamic>?)
                ?.map((e) => KanbanColumn.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
      );

  @override
  List<Object?> get props => [id, name, columns];
}

class KanbanColumn extends Equatable {
  const KanbanColumn({
    required this.id,
    required this.key,
    required this.label,
    required this.position,
    required this.color,
    required this.role,
  });

  final String id;
  final String key;
  final String label;
  final int position;
  final String color;
  final String role;

  factory KanbanColumn.fromJson(Map<String, dynamic> json) => KanbanColumn(
        id: json['id'] as String? ?? json['key'] as String? ?? '',
        key: json['key'] as String? ?? '',
        label: json['label'] as String? ?? '',
        position: json['position'] as int? ?? 0,
        color: json['color'] as String? ?? '',
        role: json['role'] as String? ?? 'custom',
      );

  @override
  List<Object?> get props => [id, key, label];
}

class KanbanTaskLabel extends Equatable {
  const KanbanTaskLabel({
    required this.id,
    required this.taskId,
    required this.name,
    required this.color,
  });

  final String id;
  final String taskId;
  final String name;
  final String color;

  factory KanbanTaskLabel.fromJson(Map<String, dynamic> json) => KanbanTaskLabel(
        id: json['id'] as String? ?? '',
        taskId: json['task_id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        color: json['color'] as String? ?? '#6366f1',
      );

  @override
  List<Object?> get props => [id, name];
}

class KanbanTask extends Equatable {
  const KanbanTask({
    required this.id,
    required this.boardId,
    required this.teamId,
    required this.taskNumber,
    required this.title,
    required this.description,
    required this.status,
    required this.position,
    this.taskKey,
    this.assigneeId,
    this.reporterId = '',
    this.startDate,
    this.dueDate,
    this.githubUrl = '',
    this.repoFullName = '',
    this.branchName = '',
    this.baseBranch = '',
    this.prNumber = 0,
    this.prUrl = '',
    this.githubState = 'none',
    this.ciStatus = 'none',
    this.githubIssueNumber = 0,
    this.priority = 'none',
    this.createdBy = '',
    this.createdAt = '',
    this.updatedAt = '',
    this.assigneeName,
    this.assigneeAvatarUrl,
    this.labels = const [],
    this.parentTaskId,
    this.parentTaskKey,
    this.parentTaskTitle,
  });

  final String id;
  final String boardId;
  final String teamId;
  final int taskNumber;
  final String? taskKey;
  final String title;
  final String description;
  final String status;
  final int position;
  final String? assigneeId;
  final String reporterId;
  final String? startDate;
  final String? dueDate;
  final String githubUrl;
  final String repoFullName;
  final String branchName;
  final String baseBranch;
  final int prNumber;
  final String prUrl;
  final String githubState;
  final String ciStatus;
  final int githubIssueNumber;
  final String priority;
  final String createdBy;
  final String createdAt;
  final String updatedAt;
  final String? assigneeName;
  final String? assigneeAvatarUrl;
  final List<KanbanTaskLabel> labels;
  final String? parentTaskId;
  final String? parentTaskKey;
  final String? parentTaskTitle;

  factory KanbanTask.fromJson(Map<String, dynamic> json) => KanbanTask(
        id: json['id'] as String,
        boardId: json['board_id'] as String,
        teamId: json['team_id'] as String? ?? '',
        taskNumber: json['task_number'] as int? ?? 0,
        taskKey: json['task_key'] as String?,
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
        status: json['status'] as String? ?? 'task',
        position: json['position'] as int? ?? 0,
        assigneeId: json['assignee_id'] as String?,
        reporterId: json['reporter_id'] as String? ?? '',
        startDate: json['start_date'] as String?,
        dueDate: json['due_date'] as String?,
        githubUrl: json['github_url'] as String? ?? '',
        repoFullName: json['repo_full_name'] as String? ?? '',
        branchName: json['branch_name'] as String? ?? '',
        baseBranch: json['base_branch'] as String? ?? '',
        prNumber: json['pr_number'] as int? ?? 0,
        prUrl: json['pr_url'] as String? ?? '',
        githubState: json['github_state'] as String? ?? 'none',
        ciStatus: json['ci_status'] as String? ?? 'none',
        githubIssueNumber: json['github_issue_number'] as int? ?? 0,
        priority: json['priority'] as String? ?? 'none',
        createdBy: json['created_by'] as String? ?? '',
        createdAt: json['created_at'] as String? ?? '',
        updatedAt: json['updated_at'] as String? ?? '',
        assigneeName: json['assignee_name'] as String?,
        assigneeAvatarUrl: json['assignee_avatar_url'] as String?,
        labels: (json['labels'] as List<dynamic>?)
                ?.map((e) => KanbanTaskLabel.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        parentTaskId: json['parent_task_id'] as String?,
        parentTaskKey: json['parent_task_key'] as String?,
        parentTaskTitle: json['parent_task_title'] as String?,
      );

  KanbanTask copyWith({
    String? status,
    int? position,
    String? title,
    String? description,
    String? priority,
    String? assigneeId,
    String? assigneeName,
    String? assigneeAvatarUrl,
    bool clearAssignee = false,
  }) {
    return KanbanTask(
      id: id,
      boardId: boardId,
      teamId: teamId,
      taskNumber: taskNumber,
      taskKey: taskKey,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      position: position ?? this.position,
      assigneeId: clearAssignee ? null : (assigneeId ?? this.assigneeId),
      reporterId: reporterId,
      startDate: startDate,
      dueDate: dueDate,
      githubUrl: githubUrl,
      repoFullName: repoFullName,
      branchName: branchName,
      baseBranch: baseBranch,
      prNumber: prNumber,
      prUrl: prUrl,
      githubState: githubState,
      ciStatus: ciStatus,
      githubIssueNumber: githubIssueNumber,
      priority: priority ?? this.priority,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt,
      assigneeName: clearAssignee ? null : (assigneeName ?? this.assigneeName),
      assigneeAvatarUrl:
          clearAssignee ? null : (assigneeAvatarUrl ?? this.assigneeAvatarUrl),
      labels: labels,
      parentTaskId: parentTaskId,
      parentTaskKey: parentTaskKey,
      parentTaskTitle: parentTaskTitle,
    );
  }

  @override
  List<Object?> get props => [id, status, position, title, priority];
}

class KanbanCommentAttachmentInput {
  const KanbanCommentAttachmentInput({
    required this.fileUrl,
    required this.fileName,
    required this.contentType,
    required this.sizeBytes,
  });

  final String fileUrl;
  final String fileName;
  final String contentType;
  final int sizeBytes;

  Map<String, dynamic> toJson() => {
        'file_url': fileUrl,
        'file_name': fileName,
        'content_type': contentType,
        'size_bytes': sizeBytes,
      };
}

class KanbanPresignResult {
  const KanbanPresignResult({
    required this.uploadUrl,
    required this.publicUrl,
    this.objectKey,
  });

  final String uploadUrl;
  final String publicUrl;
  final String? objectKey;

  factory KanbanPresignResult.fromJson(Map<String, dynamic> json) =>
      KanbanPresignResult(
        uploadUrl: json['upload_url'] as String? ?? '',
        publicUrl: json['public_url'] as String? ?? '',
        objectKey: json['object_key'] as String?,
      );
}

class KanbanTaskComment extends Equatable {
  const KanbanTaskComment({
    required this.id,
    required this.taskId,
    required this.userId,
    required this.body,
    required this.createdAt,
    this.parentId,
    this.userName,
    this.userAvatarUrl,
  });

  final String id;
  final String taskId;
  final String userId;
  final String body;
  final String createdAt;
  final String? parentId;
  final String? userName;
  final String? userAvatarUrl;

  bool get isRoot => parentId == null || parentId!.isEmpty;

  factory KanbanTaskComment.fromJson(Map<String, dynamic> json) =>
      KanbanTaskComment(
        id: json['id'] as String,
        taskId: json['task_id'] as String? ?? '',
        userId: json['user_id'] as String? ?? '',
        body: json['body'] as String? ?? '',
        createdAt: json['created_at'] as String? ?? '',
        parentId: json['parent_id'] as String?,
        userName: json['user_name'] as String?,
        userAvatarUrl: json['user_avatar_url'] as String?,
      );

  @override
  List<Object?> get props => [id, body];
}

class KanbanTaskDetail extends KanbanTask {
  const KanbanTaskDetail({
    required super.id,
    required super.boardId,
    required super.teamId,
    required super.taskNumber,
    required super.title,
    required super.description,
    required super.status,
    required super.position,
    super.taskKey,
    super.assigneeId,
    super.reporterId,
    super.startDate,
    super.dueDate,
    super.githubUrl,
    super.repoFullName,
    super.branchName,
    super.baseBranch,
    super.prNumber,
    super.prUrl,
    super.githubState,
    super.ciStatus,
    super.githubIssueNumber,
    super.priority,
    super.createdBy,
    super.createdAt,
    super.updatedAt,
    super.assigneeName,
    super.assigneeAvatarUrl,
    super.labels,
    super.parentTaskId,
    super.parentTaskKey,
    super.parentTaskTitle,
    this.comments = const [],
  });

  final List<KanbanTaskComment> comments;

  factory KanbanTaskDetail.fromJson(Map<String, dynamic> json) {
    final base = KanbanTask.fromJson(json);
    return KanbanTaskDetail(
      id: base.id,
      boardId: base.boardId,
      teamId: base.teamId,
      taskNumber: base.taskNumber,
      taskKey: base.taskKey,
      title: base.title,
      description: base.description,
      status: base.status,
      position: base.position,
      assigneeId: base.assigneeId,
      reporterId: base.reporterId,
      startDate: base.startDate,
      dueDate: base.dueDate,
      githubUrl: base.githubUrl,
      repoFullName: base.repoFullName,
      branchName: base.branchName,
      baseBranch: base.baseBranch,
      prNumber: base.prNumber,
      prUrl: base.prUrl,
      githubState: base.githubState,
      ciStatus: base.ciStatus,
      githubIssueNumber: base.githubIssueNumber,
      priority: base.priority,
      createdBy: base.createdBy,
      createdAt: base.createdAt,
      updatedAt: base.updatedAt,
      assigneeName: base.assigneeName,
      assigneeAvatarUrl: base.assigneeAvatarUrl,
      labels: base.labels,
      parentTaskId: base.parentTaskId,
      parentTaskKey: base.parentTaskKey,
      parentTaskTitle: base.parentTaskTitle,
      comments: (json['comments'] as List<dynamic>?)
              ?.map((e) => KanbanTaskComment.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}
